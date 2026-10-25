BEGIN;

-- 1. Transactional Prerequisite Assertions
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'catalog' AND table_name = 'departments') THEN
        RAISE EXCEPTION 'Prerequisite failed: catalog.departments is missing.' USING ERRCODE = 'P0002';
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'catalog' AND table_name = 'sub_departments') THEN
        RAISE EXCEPTION 'Target state changed: catalog.sub_departments already exists.' USING ERRCODE = 'P0001';
    END IF;
END $$;

-- 2. Create Base Table (Fresh Path)
CREATE TABLE catalog.sub_departments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    department_id UUID NOT NULL,
    -- code default supports legacy writers that omit code, ensuring NOT NULL compatibility
    code VARCHAR NOT NULL DEFAULT 'SD_' || replace(gen_random_uuid()::text, '-', ''),
    name TEXT NOT NULL,
    title_display_name TEXT,
    description TEXT,
    status TEXT NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    
    CONSTRAINT uq_sub_departments_code UNIQUE (code),
    CONSTRAINT fk_sub_dept_parent FOREIGN KEY (department_id) REFERENCES catalog.departments(id) ON DELETE RESTRICT,
    CONSTRAINT chk_sub_dept_status CHECK (status IN ('ACTIVE', 'INACTIVE')),
    CONSTRAINT chk_sub_dept_code_not_blank CHECK (trim(code) <> ''),
    CONSTRAINT chk_sub_dept_name_not_blank CHECK (trim(name) <> '')
);

CREATE UNIQUE INDEX idx_uq_sub_dept_name ON catalog.sub_departments (department_id, lower(trim(name)));

-- 3. Public Read View
CREATE VIEW public.sub_departments AS 
SELECT id, department_id, code, name, title_display_name, description, status, created_at, updated_at 
FROM catalog.sub_departments;

REVOKE ALL PRIVILEGES ON TABLE catalog.sub_departments FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.sub_departments FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.sub_departments TO authenticated, service_role;

-- 4. Create/Update RPCs
CREATE OR REPLACE FUNCTION catalog.create_sub_department_impl(
    p_department_id UUID, p_code TEXT, p_name TEXT, p_title_display_name TEXT, p_desc TEXT, p_status TEXT, p_actor UUID
) RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE v_res JSON;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM catalog.departments WHERE id = p_department_id AND status = 'ACTIVE') THEN
        RAISE EXCEPTION 'Parent department does not exist or is inactive' USING ERRCODE = 'P0002';
    END IF;

    -- Use the default UUID generation for code if explicitly omitted to mimic legacy compatibility
    INSERT INTO catalog.sub_departments (department_id, code, name, title_display_name, description, status, created_by, updated_by)
    VALUES (
        p_department_id, 
        COALESCE(p_code, 'SD_' || replace(gen_random_uuid()::text, '-', '')), 
        p_name, p_title_display_name, p_desc, COALESCE(p_status, 'ACTIVE'), p_actor, p_actor
    )
    RETURNING row_to_json(sub_departments.*) INTO v_res;
    
    RETURN v_res;
END;
$$;

CREATE OR REPLACE FUNCTION catalog.update_sub_department_impl(
    p_id UUID, p_department_id UUID, p_code TEXT, p_name TEXT, p_update_title BOOLEAN, p_title_display_name TEXT, p_update_desc BOOLEAN, p_desc TEXT, p_status TEXT, p_actor UUID
) RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
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

        EXECUTE 'SELECT 1 FROM catalog.sub_department_designations WHERE sub_department_id = $1 LIMIT 1' INTO v_res USING p_id;
        IF v_res IS NOT NULL THEN
            RAISE EXCEPTION 'Cannot reassign parent department because active designation mappings exist' USING ERRCODE = 'P0001';
        END IF;
    END IF;

    IF p_status IS NOT NULL AND p_status = 'INACTIVE' AND v_old_status = 'ACTIVE' THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='catalog' AND table_name='sub_department_designations') THEN
            RAISE EXCEPTION 'Dependency safety cannot be verified (missing catalog.sub_department_designations). Deactivation is blocked.' USING ERRCODE = 'P0001';
        END IF;

        EXECUTE 'SELECT 1 FROM catalog.sub_department_designations WHERE sub_department_id = $1 LIMIT 1' INTO v_res USING p_id;
        IF v_res IS NOT NULL THEN
            RAISE EXCEPTION 'Cannot deactivate sub-department because active designation mappings exist' USING ERRCODE = 'P0001';
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
$$;

-- 5. Public Wrappers & Grants (Restricted Access)
CREATE OR REPLACE FUNCTION public.rpc_create_sub_department(p_department_id UUID, p_code TEXT, p_name TEXT, p_title_display_name TEXT, p_desc TEXT, p_status TEXT, p_actor UUID) RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$ BEGIN RETURN catalog.create_sub_department_impl(p_department_id, p_code, p_name, p_title_display_name, p_desc, p_status, p_actor); END; $$;
CREATE OR REPLACE FUNCTION public.rpc_update_sub_department(p_id UUID, p_department_id UUID, p_code TEXT, p_name TEXT, p_update_title BOOLEAN, p_title_display_name TEXT, p_update_desc BOOLEAN, p_desc TEXT, p_status TEXT, p_actor UUID) RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$ BEGIN RETURN catalog.update_sub_department_impl(p_id, p_department_id, p_code, p_name, p_update_title, p_title_display_name, p_update_desc, p_desc, p_status, p_actor); END; $$;

-- Strip public execution privileges completely, grant ONLY to service_role
REVOKE EXECUTE ON FUNCTION catalog.create_sub_department_impl(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, UUID) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION catalog.update_sub_department_impl(UUID, UUID, TEXT, TEXT, BOOLEAN, TEXT, BOOLEAN, TEXT, TEXT, UUID) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.rpc_create_sub_department(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, UUID) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.rpc_update_sub_department(UUID, UUID, TEXT, TEXT, BOOLEAN, TEXT, BOOLEAN, TEXT, TEXT, UUID) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.rpc_create_sub_department(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.rpc_update_sub_department(UUID, UUID, TEXT, TEXT, BOOLEAN, TEXT, BOOLEAN, TEXT, TEXT, UUID) TO service_role;

COMMIT;