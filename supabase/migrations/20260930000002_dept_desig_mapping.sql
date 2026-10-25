BEGIN;

-- ============================================================================
-- Migration: 20260930000002_dept_desig_mapping.sql  (corrected v2)
-- Prerequisite: 20260930000001_department_designation.sql applied.
-- This migration is FORWARD ONLY. No existing tables/columns are dropped.
-- ============================================================================

-- ── 1. New columns on existing tables (IF NOT EXISTS for idempotency) ────────

ALTER TABLE catalog.departments
    ADD COLUMN IF NOT EXISTS title_display_name TEXT;

ALTER TABLE catalog.designations
    ADD COLUMN IF NOT EXISTS title_mode VARCHAR NOT NULL DEFAULT 'FIXED'
        CONSTRAINT chk_title_mode CHECK (title_mode IN ('DEPARTMENT_BASED', 'FIXED'));

ALTER TABLE catalog.designations
    ADD COLUMN IF NOT EXISTS title_template TEXT;

-- ── 2. Improved template constraint (drop old incomplete version first) ───────
-- Old constraint allowed: DEPARTMENT_BASED with NULL/blank template,
-- FIXED with non-NULL template, and other {placeholder} patterns.

ALTER TABLE catalog.designations
    DROP CONSTRAINT IF EXISTS chk_designation_template;

-- Rules:
--   DEPARTMENT_BASED → template NOT NULL, non-blank, contains {department},
--                      NO other {placeholder} patterns permitted
--   FIXED            → template MUST be NULL (explicit FIXED transition always clears)

ALTER TABLE catalog.designations
    ADD CONSTRAINT chk_designation_template CHECK (
        (
            title_mode = 'DEPARTMENT_BASED'
            AND title_template IS NOT NULL
            AND trim(title_template) <> ''
            AND title_template LIKE '%{department}%'
            -- After removing {department}, no other {…} placeholders may remain
            AND regexp_replace(title_template, '\{department\}', '', 'g') !~ '\{[^}]*\}'
        )
        OR
        (
            title_mode = 'FIXED'
            AND title_template IS NULL
        )
    );

-- ── 3. Mapping junction table ────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS catalog.department_designations (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    department_id   UUID        NOT NULL
                        REFERENCES catalog.departments(id) ON DELETE CASCADE,
    designation_id  UUID        NOT NULL
                        REFERENCES catalog.designations(id) ON DELETE CASCADE,
    status          VARCHAR     NOT NULL DEFAULT 'ACTIVE'
                        CHECK (status IN ('ACTIVE', 'INACTIVE')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by      UUID,
    updated_by      UUID,
    CONSTRAINT uq_dept_desig UNIQUE (department_id, designation_id)
);

ALTER TABLE catalog.department_designations ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog.department_designations FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Service Role Access" ON catalog.department_designations;
CREATE POLICY "Service Role Access" ON catalog.department_designations
    FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);

-- ── 4. Public view updates ────────────────────────────────────────────────────
-- IMPORTANT: No DROP CASCADE on existing views that may have dependents.
-- Existing column order is PRESERVED; new columns appended at end.
-- View for public.departments and public.designations existed in migration 0001.
-- We use CREATE OR REPLACE which safely appends columns without CASCADE.

-- departments: original cols preserved → title_display_name appended last
CREATE OR REPLACE VIEW public.departments AS
    SELECT
        id,
        code,
        name,
        description,
        status,
        created_at,
        updated_at,
        title_display_name          -- new: appended, does not shift existing ordinals
    FROM catalog.departments;

-- Revoke PUBLIC / anon; authenticated and service_role only (GC approved policy)
REVOKE ALL ON public.departments FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON public.departments TO authenticated, service_role;

-- designations: original cols preserved → title_mode, title_template appended last
CREATE OR REPLACE VIEW public.designations AS
    SELECT
        id,
        code,
        name,
        description,
        status,
        created_at,
        updated_at,
        title_mode,                 -- new
        title_template              -- new
    FROM catalog.designations;

REVOKE ALL ON public.designations FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON public.designations TO authenticated, service_role;

-- department_designations: new view, no prior dependents
CREATE OR REPLACE VIEW public.department_designations AS
    SELECT id, department_id, designation_id, status
    FROM catalog.department_designations;

REVOKE ALL ON public.department_designations FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON public.department_designations TO authenticated, service_role;

-- ── 5. Internal SECURITY DEFINER implementations ─────────────────────────────
-- All internal functions: REVOKE from PUBLIC, anon, authenticated immediately.
-- Only service_role may call public wrappers.

-- ── Departments ──────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION catalog.create_department_impl(
    p_code               TEXT,
    p_name               TEXT,
    p_title_display_name TEXT,
    p_desc               TEXT,
    p_status             TEXT,
    p_actor              UUID
) RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE v_res JSON;
BEGIN
    INSERT INTO catalog.departments
        (code, name, title_display_name, description, status, created_by, updated_by)
    VALUES
        (p_code, p_name, p_title_display_name, p_desc,
         COALESCE(p_status, 'ACTIVE'), p_actor, p_actor)
    RETURNING row_to_json(departments.*) INTO v_res;
    RETURN v_res;
END;
$$;

REVOKE EXECUTE ON FUNCTION catalog.create_department_impl(TEXT,TEXT,TEXT,TEXT,TEXT,UUID)
    FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION catalog.update_department_impl(
    p_id                 UUID,
    p_code               TEXT,
    p_name               TEXT,
    p_title_display_name TEXT,
    p_desc               TEXT,
    p_status             TEXT,
    p_actor              UUID
) RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE v_res JSON;
BEGIN
    -- Omitted (NULL) fields preserve existing values.
    UPDATE catalog.departments SET
        code               = COALESCE(p_code, code),
        name               = COALESCE(p_name, name),
        title_display_name = CASE WHEN p_title_display_name IS NOT NULL
                                   THEN p_title_display_name
                                   ELSE title_display_name END,
        description        = CASE WHEN p_desc IS NOT NULL
                                   THEN p_desc
                                   ELSE description END,
        status             = COALESCE(p_status, status),
        updated_at         = NOW(),
        updated_by         = p_actor
    WHERE id = p_id
    RETURNING row_to_json(departments.*) INTO v_res;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Department not found: %', p_id USING ERRCODE = 'P0002';
    END IF;
    RETURN v_res;
END;
$$;

REVOKE EXECUTE ON FUNCTION catalog.update_department_impl(UUID,TEXT,TEXT,TEXT,TEXT,TEXT,UUID)
    FROM PUBLIC, anon, authenticated;

-- ── Designations ─────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION catalog.create_designation_impl(
    p_code          TEXT,
    p_name          TEXT,
    p_title_mode    TEXT,
    p_title_template TEXT,
    p_desc          TEXT,
    p_status        TEXT,
    p_actor         UUID
) RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE v_res JSON;
BEGIN
    INSERT INTO catalog.designations
        (code, name, title_mode, title_template,
         description, status, created_by, updated_by)
    VALUES
        (p_code, p_name, COALESCE(p_title_mode, 'FIXED'), p_title_template,
         p_desc, COALESCE(p_status, 'ACTIVE'), p_actor, p_actor)
    RETURNING row_to_json(designations.*) INTO v_res;
    RETURN v_res;
END;
$$;

REVOKE EXECUTE ON FUNCTION catalog.create_designation_impl(TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,UUID)
    FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION catalog.update_designation_impl(
    p_id             UUID,
    p_code           TEXT,
    p_name           TEXT,
    p_title_mode     TEXT,
    p_title_template TEXT,
    p_desc           TEXT,
    p_status         TEXT,
    p_actor          UUID
) RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_res          JSON;
    v_current_mode VARCHAR;
    v_eff_mode     VARCHAR;
    v_eff_template TEXT;
BEGIN
    -- Read current state; raise P0002 if not found
    SELECT title_mode, title_template
    INTO v_current_mode, v_eff_template
    FROM catalog.designations WHERE id = p_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Designation not found: %', p_id USING ERRCODE = 'P0002';
    END IF;

    -- Effective mode: use provided or keep current
    v_eff_mode := COALESCE(p_title_mode, v_current_mode);

    -- Template semantics:
    --   Transition to FIXED (any means)         → NULL (always clears, no exceptions)
    --   Remain DEPARTMENT_BASED + value given   → use provided value
    --   Remain DEPARTMENT_BASED + omitted       → preserve existing template
    IF v_eff_mode = 'FIXED' THEN
        v_eff_template := NULL;
    ELSIF p_title_template IS NOT NULL THEN
        v_eff_template := p_title_template;
    END IF;
    -- else: v_eff_template already holds current value from SELECT above

    UPDATE catalog.designations SET
        code           = COALESCE(p_code, code),
        name           = COALESCE(p_name, name),
        title_mode     = v_eff_mode,
        title_template = v_eff_template,
        description    = CASE WHEN p_desc IS NOT NULL THEN p_desc ELSE description END,
        status         = COALESCE(p_status, status),
        updated_at     = NOW(),
        updated_by     = p_actor
    WHERE id = p_id
    RETURNING row_to_json(designations.*) INTO v_res;

    RETURN v_res;
END;
$$;

REVOKE EXECUTE ON FUNCTION catalog.update_designation_impl(UUID,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,UUID)
    FROM PUBLIC, anon, authenticated;

-- ── Sync Mapping (improved) ──────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION catalog.sync_department_designations_impl(
    p_department_id   UUID,
    p_designation_ids UUID[],
    p_actor           UUID,
    p_explicit_clear  BOOLEAN DEFAULT FALSE
) RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_clean_ids    UUID[];
    v_invalid_ids  UUID[];
    v_active_count INT;
BEGIN
    -- 1. Department must exist and lock for concurrent syncs
    PERFORM 1 FROM catalog.departments WHERE id = p_department_id FOR UPDATE;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Department not found: %', p_department_id
            USING ERRCODE = 'P0002';
    END IF;

    -- 2. Deduplicate and strip NULLs from input array
    SELECT ARRAY(
        SELECT DISTINCT d_id
        FROM unnest(p_designation_ids) AS d_id
        WHERE d_id IS NOT NULL
        ORDER BY d_id
    ) INTO v_clean_ids;

    -- 3. Validate every supplied ID references an existing designation
    SELECT ARRAY_AGG(d_id) INTO v_invalid_ids
    FROM unnest(v_clean_ids) AS d_id
    WHERE NOT EXISTS (
        SELECT 1 FROM catalog.designations WHERE id = d_id
    );

    IF v_invalid_ids IS NOT NULL AND array_length(v_invalid_ids, 1) > 0 THEN
        RAISE EXCEPTION 'Unknown designation IDs: %', v_invalid_ids::TEXT
            USING ERRCODE = '22023';
    END IF;

    -- 4. Deactivate dropped designations ONLY when:
    --    (a) caller supplied ≥1 valid ID (normal update), OR
    --    (b) caller explicitly set p_explicit_clear = TRUE (intentional wipe)
    --    Empty input without p_explicit_clear = TRUE does NOT deactivate anything.
    IF array_length(v_clean_ids, 1) > 0 OR p_explicit_clear THEN
        UPDATE catalog.department_designations
        SET status     = 'INACTIVE',
            updated_at = NOW(),
            updated_by = p_actor
        WHERE department_id = p_department_id
          AND status = 'ACTIVE'
          AND NOT (designation_id = ANY(v_clean_ids));
    END IF;

    -- 5. Upsert active mappings
    IF array_length(v_clean_ids, 1) > 0 THEN
        INSERT INTO catalog.department_designations
            (department_id, designation_id, status, created_by, updated_by)
        SELECT p_department_id, d_id, 'ACTIVE', p_actor, p_actor
        FROM unnest(v_clean_ids) AS d_id
        ON CONFLICT (department_id, designation_id) DO UPDATE
            SET status     = 'ACTIVE',
                updated_at = NOW(),
                updated_by = p_actor;
    END IF;

    SELECT COUNT(*) INTO v_active_count
    FROM catalog.department_designations
    WHERE department_id = p_department_id AND status = 'ACTIVE';

    RETURN json_build_object('success', true, 'active_count', v_active_count);
END;
$$;

REVOKE EXECUTE ON FUNCTION
    catalog.sync_department_designations_impl(UUID, UUID[], UUID, BOOLEAN)
    FROM PUBLIC, anon, authenticated;

-- ── 6. Drop old public wrappers (old 5-arg signatures from migration 0001) ───
-- Callers in 0001: rpc_create_department(code,name,desc,status,actor)
-- New signatures add title_display_name / title_mode / title_template.
-- Old signatures are incompatible; drop cleanly before re-creating.

DROP FUNCTION IF EXISTS public.rpc_create_department(TEXT, TEXT, TEXT, TEXT, UUID);
DROP FUNCTION IF EXISTS public.rpc_update_department(UUID, TEXT, TEXT, TEXT, TEXT, UUID);
DROP FUNCTION IF EXISTS public.rpc_create_designation(TEXT, TEXT, TEXT, TEXT, UUID);
DROP FUNCTION IF EXISTS public.rpc_update_designation(UUID, TEXT, TEXT, TEXT, TEXT, UUID);
-- Drop the 3-arg sync if it was left from previous iteration of this migration
DROP FUNCTION IF EXISTS public.rpc_sync_department_designations(UUID, UUID[], UUID);

-- ── 7. New public RPC wrappers ────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.rpc_create_department(
    p_code               TEXT,
    p_name               TEXT,
    p_title_display_name TEXT,
    p_desc               TEXT,
    p_status             TEXT,
    p_actor              UUID
) RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $$ BEGIN
    RETURN catalog.create_department_impl(
        p_code, p_name, p_title_display_name, p_desc, p_status, p_actor);
END; $$;

CREATE OR REPLACE FUNCTION public.rpc_update_department(
    p_id                 UUID,
    p_code               TEXT,
    p_name               TEXT,
    p_title_display_name TEXT,
    p_desc               TEXT,
    p_status             TEXT,
    p_actor              UUID
) RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $$ BEGIN
    RETURN catalog.update_department_impl(
        p_id, p_code, p_name, p_title_display_name, p_desc, p_status, p_actor);
END; $$;

CREATE OR REPLACE FUNCTION public.rpc_create_designation(
    p_code           TEXT,
    p_name           TEXT,
    p_title_mode     TEXT,
    p_title_template TEXT,
    p_desc           TEXT,
    p_status         TEXT,
    p_actor          UUID
) RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $$ BEGIN
    RETURN catalog.create_designation_impl(
        p_code, p_name, p_title_mode, p_title_template, p_desc, p_status, p_actor);
END; $$;

CREATE OR REPLACE FUNCTION public.rpc_update_designation(
    p_id             UUID,
    p_code           TEXT,
    p_name           TEXT,
    p_title_mode     TEXT,
    p_title_template TEXT,
    p_desc           TEXT,
    p_status         TEXT,
    p_actor          UUID
) RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $$ BEGIN
    RETURN catalog.update_designation_impl(
        p_id, p_code, p_name, p_title_mode, p_title_template,
        p_desc, p_status, p_actor);
END; $$;

CREATE OR REPLACE FUNCTION public.rpc_sync_department_designations(
    p_department_id   UUID,
    p_designation_ids UUID[],
    p_actor           UUID,
    p_explicit_clear  BOOLEAN DEFAULT FALSE
) RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $$ BEGIN
    RETURN catalog.sync_department_designations_impl(
        p_department_id, p_designation_ids, p_actor, p_explicit_clear);
END; $$;

-- ── 8. Revoke from PUBLIC/anon/authenticated; grant only to service_role ─────

REVOKE EXECUTE ON FUNCTION
    public.rpc_create_department(TEXT, TEXT, TEXT, TEXT, TEXT, UUID)
    FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION
    public.rpc_update_department(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, UUID)
    FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION
    public.rpc_create_designation(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, UUID)
    FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION
    public.rpc_update_designation(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, UUID)
    FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION
    public.rpc_sync_department_designations(UUID, UUID[], UUID, BOOLEAN)
    FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION
    public.rpc_create_department(TEXT, TEXT, TEXT, TEXT, TEXT, UUID)
    TO service_role;
GRANT EXECUTE ON FUNCTION
    public.rpc_update_department(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, UUID)
    TO service_role;
GRANT EXECUTE ON FUNCTION
    public.rpc_create_designation(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, UUID)
    TO service_role;
GRANT EXECUTE ON FUNCTION
    public.rpc_update_designation(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, UUID)
    TO service_role;
GRANT EXECUTE ON FUNCTION
    public.rpc_sync_department_designations(UUID, UUID[], UUID, BOOLEAN)
    TO service_role;

COMMIT;
