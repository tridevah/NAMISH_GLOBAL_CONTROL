-- Migration 0004: Sub-department Designations Master
BEGIN;

-- 1. Prerequisite Checks
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'catalog' AND table_name = 'sub_departments') THEN
        RAISE EXCEPTION 'Prerequisite failed: catalog.sub_departments is missing.' USING ERRCODE = 'P0002';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'catalog' AND table_name = 'department_designations') THEN
        RAISE EXCEPTION 'Prerequisite failed: catalog.department_designations is missing.' USING ERRCODE = 'P0002';
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'catalog' AND table_name = 'sub_department_designations') THEN
        RAISE EXCEPTION 'Target state changed: catalog.sub_department_designations already exists.' USING ERRCODE = 'P0001';
    END IF;
END $$;

-- 2. Create Mapping Table
CREATE TABLE catalog.sub_department_designations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sub_department_id UUID NOT NULL,
    designation_id UUID NOT NULL,
    status TEXT NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    
    CONSTRAINT uq_sub_dept_designation UNIQUE (sub_department_id, designation_id),
    CONSTRAINT fk_sub_dept_mapping FOREIGN KEY (sub_department_id) REFERENCES catalog.sub_departments(id) ON DELETE RESTRICT,
    CONSTRAINT fk_designation_mapping FOREIGN KEY (designation_id) REFERENCES catalog.designations(id) ON DELETE RESTRICT,
    CONSTRAINT chk_mapping_status CHECK (status IN ('ACTIVE', 'INACTIVE'))
);

-- 3. Public Read View
CREATE VIEW public.sub_department_designations AS 
SELECT id, sub_department_id, designation_id, status, created_at, updated_at 
FROM catalog.sub_department_designations;

REVOKE ALL PRIVILEGES ON TABLE catalog.sub_department_designations FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.sub_department_designations FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.sub_department_designations TO authenticated, service_role;

-- 4. Patch 0003 Update Logic for Compatibility
CREATE OR REPLACE FUNCTION catalog.update_sub_department_impl(
    p_id UUID, p_department_id UUID, p_code TEXT, p_name TEXT, p_update_title BOOLEAN, p_title_display_name TEXT, p_update_desc BOOLEAN, p_desc TEXT, p_status TEXT, p_actor UUID
) RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $func$
DECLARE 
    v_res JSON;
    v_old_dept_id UUID;
    v_old_status TEXT;
BEGIN
    SELECT department_id, status INTO v_old_dept_id, v_old_status FROM catalog.sub_departments WHERE id = p_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Sub-department not found' USING ERRCODE = 'P0002';
    END IF;

    IF p_department_id IS NOT NULL AND p_department_id != v_old_dept_id THEN
        IF NOT EXISTS (SELECT 1 FROM catalog.departments WHERE id = p_department_id AND status = 'ACTIVE') THEN
            RAISE EXCEPTION 'Cannot reassign to an inactive or non-existent parent department' USING ERRCODE = 'P0002';
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='catalog' AND table_name='sub_department_designations') THEN
            RAISE EXCEPTION 'Dependency safety cannot be verified (missing catalog.sub_department_designations). Parent reassignment is blocked.' USING ERRCODE = 'P0001';
        END IF;

        EXECUTE 'SELECT 1 FROM catalog.sub_department_designations WHERE sub_department_id = $1 AND status = ''ACTIVE'' LIMIT 1' INTO v_res USING p_id;
        IF v_res IS NOT NULL THEN
            RAISE EXCEPTION 'Cannot reassign parent department because active designation mappings exist' USING ERRCODE = 'P0001';
        END IF;
        
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='catalog' AND table_name='hr_submissions') THEN
            RAISE EXCEPTION 'Dependency safety cannot be verified against hr_submissions. Parent reassignment is blocked.' USING ERRCODE = 'P0001';
        END IF;
    END IF;

    IF p_status IS NOT NULL AND p_status = 'INACTIVE' AND v_old_status = 'ACTIVE' THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='catalog' AND table_name='sub_department_designations') THEN
            RAISE EXCEPTION 'Dependency safety cannot be verified (missing catalog.sub_department_designations). Deactivation is blocked.' USING ERRCODE = 'P0001';
        END IF;

        EXECUTE 'SELECT 1 FROM catalog.sub_department_designations WHERE sub_department_id = $1 AND status = ''ACTIVE'' LIMIT 1' INTO v_res USING p_id;
        IF v_res IS NOT NULL THEN
            RAISE EXCEPTION 'Cannot deactivate sub-department because active designation mappings exist' USING ERRCODE = 'P0001';
        END IF;
        
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='catalog' AND table_name='hr_submissions') THEN
            RAISE EXCEPTION 'Dependency safety cannot be verified against hr_submissions. Deactivation is blocked.' USING ERRCODE = 'P0001';
        END IF;
    END IF;

    UPDATE catalog.sub_departments SET
        department_id = COALESCE(p_department_id, department_id),
        code = COALESCE(p_code, code),
        name = COALESCE(p_name, name),
        title_display_name = CASE WHEN p_update_title THEN p_title_display_name ELSE title_display_name END,
        description = CASE WHEN p_update_desc THEN p_desc ELSE description END,
        status = COALESCE(p_status, status),
        updated_at = NOW(),
        updated_by = p_actor
    WHERE id = p_id
    RETURNING row_to_json(sub_departments.*) INTO v_res;
    
    RETURN v_res;
END;
$func$;

-- 5. Mutation RPCs for Assignments
CREATE OR REPLACE FUNCTION catalog.update_sub_dept_designations_impl(
    p_sub_dept_id UUID,
    p_add_ids UUID[],
    p_remove_ids UUID[],
    p_actor UUID
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $func$
DECLARE
    v_sd_status TEXT;
    v_parent_id UUID;
    v_parent_status TEXT;
    v_id UUID;
    v_desig_status TEXT;
    v_eligible BOOLEAN;
    v_overlap BOOLEAN;
BEGIN
    IF p_add_ids IS NULL THEN p_add_ids := '{}'::UUID[]; END IF;
    IF p_remove_ids IS NULL THEN p_remove_ids := '{}'::UUID[]; END IF;

    IF array_position(p_add_ids, NULL) IS NOT NULL OR array_position(p_remove_ids, NULL) IS NOT NULL THEN
        RAISE EXCEPTION 'Arrays cannot contain null elements' USING ERRCODE = '22004';
    END IF;

    IF (SELECT count(DISTINCT unnest) != array_length(p_add_ids, 1) FROM unnest(p_add_ids) WHERE array_length(p_add_ids, 1) > 0) THEN
        RAISE EXCEPTION 'Duplicate IDs are not allowed in add_ids' USING ERRCODE = '2202E';
    END IF;

    IF (SELECT count(DISTINCT unnest) != array_length(p_remove_ids, 1) FROM unnest(p_remove_ids) WHERE array_length(p_remove_ids, 1) > 0) THEN
        RAISE EXCEPTION 'Duplicate IDs are not allowed in remove_ids' USING ERRCODE = '2202E';
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM unnest(p_add_ids) a JOIN unnest(p_remove_ids) r ON a = r
    ) INTO v_overlap;
    IF v_overlap THEN
        RAISE EXCEPTION 'Cannot add and remove the same designation simultaneously' USING ERRCODE = '2202E';
    END IF;

    SELECT department_id, status INTO v_parent_id, v_sd_status FROM catalog.sub_departments WHERE id = p_sub_dept_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Sub-department not found' USING ERRCODE = 'P0002';
    END IF;

    IF array_length(p_add_ids, 1) > 0 THEN
        IF v_sd_status != 'ACTIVE' THEN
            RAISE EXCEPTION 'Cannot assign designations to an inactive sub-department' USING ERRCODE = 'P0001';
        END IF;
        
        SELECT status INTO v_parent_status FROM catalog.departments WHERE id = v_parent_id FOR SHARE;
        IF v_parent_status != 'ACTIVE' THEN
            RAISE EXCEPTION 'Cannot assign designations when parent department is inactive' USING ERRCODE = 'P0001';
        END IF;
        
        FOREACH v_id IN ARRAY p_add_ids
        LOOP
            SELECT status INTO v_desig_status FROM catalog.designations WHERE id = v_id FOR SHARE;
            IF NOT FOUND THEN
                RAISE EXCEPTION 'Designation % not found', v_id USING ERRCODE = 'P0002';
            END IF;
            IF v_desig_status != 'ACTIVE' THEN
                RAISE EXCEPTION 'Cannot assign inactive designation %', v_id USING ERRCODE = 'P0001';
            END IF;
            
            -- Mandatory Parent Eligibility Check
            SELECT EXISTS (
                SELECT 1 FROM catalog.department_designations 
                WHERE department_id = v_parent_id AND designation_id = v_id AND status = 'ACTIVE'
                FOR SHARE
            ) INTO v_eligible;
            
            IF NOT v_eligible THEN
                RAISE EXCEPTION 'Designation % is not eligible for the parent department', v_id USING ERRCODE = 'P0001';
            END IF;
        END LOOP;
        
        INSERT INTO catalog.sub_department_designations (sub_department_id, designation_id, status, created_by, updated_by)
        SELECT p_sub_dept_id, unnest(p_add_ids), 'ACTIVE', p_actor, p_actor
        ON CONFLICT (sub_department_id, designation_id) DO UPDATE SET
            status = 'ACTIVE',
            updated_at = NOW(),
            updated_by = p_actor
        WHERE catalog.sub_department_designations.status != 'ACTIVE';
    END IF;

    IF array_length(p_remove_ids, 1) > 0 THEN
        UPDATE catalog.sub_department_designations SET
            status = 'INACTIVE',
            updated_at = NOW(),
            updated_by = p_actor
        WHERE sub_department_id = p_sub_dept_id AND designation_id = ANY(p_remove_ids) AND status = 'ACTIVE';
    END IF;
END;
$func$;

CREATE OR REPLACE FUNCTION public.rpc_update_sub_dept_designations(p_sub_dept_id UUID, p_add_ids UUID[], p_remove_ids UUID[], p_actor UUID) 
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $func$ 
BEGIN 
    PERFORM catalog.update_sub_dept_designations_impl(p_sub_dept_id, p_add_ids, p_remove_ids, p_actor); 
END; 
$func$;

REVOKE EXECUTE ON FUNCTION catalog.update_sub_dept_designations_impl(UUID, UUID[], UUID[], UUID) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.rpc_update_sub_dept_designations(UUID, UUID[], UUID[], UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_update_sub_dept_designations(UUID, UUID[], UUID[], UUID) TO service_role;

-- 6. Dependency Guard on Parent Department Designations sync
CREATE OR REPLACE FUNCTION catalog.sync_department_designations_impl(
    p_department_id   UUID,
    p_designation_ids UUID[],
    p_actor           UUID,
    p_explicit_clear  BOOLEAN DEFAULT FALSE
) RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $func$
DECLARE
    v_clean_ids    UUID[];
    v_invalid_ids  UUID[];
    v_active_count INT;
BEGIN
    PERFORM 1 FROM catalog.departments WHERE id = p_department_id FOR UPDATE;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Department not found: %', p_department_id
            USING ERRCODE = 'P0002';
    END IF;

    SELECT ARRAY(
        SELECT DISTINCT d_id
        FROM unnest(p_designation_ids) AS d_id
        WHERE d_id IS NOT NULL
        ORDER BY d_id
    ) INTO v_clean_ids;

    SELECT ARRAY_AGG(d_id) INTO v_invalid_ids
    FROM unnest(v_clean_ids) AS d_id
    WHERE NOT EXISTS (
        SELECT 1 FROM catalog.designations WHERE id = d_id
    );

    IF v_invalid_ids IS NOT NULL AND array_length(v_invalid_ids, 1) > 0 THEN
        RAISE EXCEPTION 'Unknown designation IDs: %', v_invalid_ids::TEXT
            USING ERRCODE = '22023';
    END IF;

    IF array_length(v_clean_ids, 1) > 0 OR p_explicit_clear THEN
        -- Dependency Guard: Check for active sub-department assignments
        IF EXISTS (
            SELECT 1
            FROM catalog.department_designations dd
            JOIN catalog.sub_departments sd ON sd.department_id = dd.department_id
            JOIN catalog.sub_department_designations sdd ON sdd.sub_department_id = sd.id AND sdd.designation_id = dd.designation_id
            WHERE dd.department_id = p_department_id
              AND dd.status = 'ACTIVE'
              AND NOT (dd.designation_id = ANY(v_clean_ids))
              AND sdd.status = 'ACTIVE'
        ) THEN
            RAISE EXCEPTION 'Cannot deactivate parent designation because active sub-department assignments exist' USING ERRCODE = 'P0001';
        END IF;

        UPDATE catalog.department_designations
        SET status     = 'INACTIVE',
            updated_at = NOW(),
            updated_by = p_actor
        WHERE department_id = p_department_id
          AND status = 'ACTIVE'
          AND NOT (designation_id = ANY(v_clean_ids));
    END IF;

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
$func$;

COMMIT;