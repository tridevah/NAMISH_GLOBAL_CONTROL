BEGIN;

-- 1. Departments Table
CREATE TABLE catalog.departments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR NOT NULL,
    name VARCHAR NOT NULL,
    description TEXT,
    status VARCHAR NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    CONSTRAINT uq_departments_code UNIQUE (code)
);

ALTER TABLE catalog.departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog.departments FORCE ROW LEVEL SECURITY;
CREATE POLICY "Service Role Access" ON catalog.departments FOR ALL USING (auth.role() = 'service_role');

-- 2. Designations Table
CREATE TABLE catalog.designations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR NOT NULL,
    name VARCHAR NOT NULL,
    description TEXT,
    status VARCHAR NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    CONSTRAINT uq_designations_code UNIQUE (code)
);

ALTER TABLE catalog.designations ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog.designations FORCE ROW LEVEL SECURITY;
CREATE POLICY "Service Role Access" ON catalog.designations FOR ALL USING (auth.role() = 'service_role');

-- 3. Public Views
DROP VIEW IF EXISTS public.departments;
CREATE VIEW public.departments AS SELECT id, code, name, description, status, created_at, updated_at FROM catalog.departments;
DROP VIEW IF EXISTS public.designations;
CREATE VIEW public.designations AS SELECT id, code, name, description, status, created_at, updated_at FROM catalog.designations;

-- 4. Grants on tables and views
GRANT SELECT ON catalog.departments TO service_role;
GRANT SELECT ON catalog.designations TO service_role;

REVOKE ALL ON public.departments FROM PUBLIC, anon;
REVOKE ALL ON public.designations FROM PUBLIC, anon;
GRANT SELECT ON public.departments TO authenticated, service_role;
GRANT SELECT ON public.designations TO authenticated, service_role;

-- 5. RPC Implementations
CREATE OR REPLACE FUNCTION catalog.create_department_impl(
    p_code TEXT, p_name TEXT, p_desc TEXT, p_status TEXT, p_actor UUID
) RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE v_res JSON;
BEGIN
    INSERT INTO catalog.departments (code, name, description, status, created_by, updated_by)
    VALUES (p_code, p_name, p_desc, p_status, p_actor, p_actor)
    RETURNING row_to_json(departments.*) INTO v_res;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Department not found' USING ERRCODE = 'P0002';
    END IF;
    RETURN v_res;
END;
$$;

CREATE OR REPLACE FUNCTION catalog.update_department_impl(
    p_id UUID, p_code TEXT, p_name TEXT, p_desc TEXT, p_status TEXT, p_actor UUID
) RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE v_res JSON;
BEGIN
    UPDATE catalog.departments SET
        code = COALESCE(p_code, code),
        name = COALESCE(p_name, name),
        description = CASE WHEN p_desc IS NOT NULL THEN p_desc ELSE description END,
        status = COALESCE(p_status, status),
        updated_at = NOW(),
        updated_by = p_actor
    WHERE id = p_id
    RETURNING row_to_json(departments.*) INTO v_res;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Department not found' USING ERRCODE = 'P0002';
    END IF;
    RETURN v_res;
END;
$$;

CREATE OR REPLACE FUNCTION catalog.create_designation_impl(
    p_code TEXT, p_name TEXT, p_desc TEXT, p_status TEXT, p_actor UUID
) RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE v_res JSON;
BEGIN
    INSERT INTO catalog.designations (code, name, description, status, created_by, updated_by)
    VALUES (p_code, p_name, p_desc, p_status, p_actor, p_actor)
    RETURNING row_to_json(designations.*) INTO v_res;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Designation not found' USING ERRCODE = 'P0002';
    END IF;
    RETURN v_res;
END;
$$;

CREATE OR REPLACE FUNCTION catalog.update_designation_impl(
    p_id UUID, p_code TEXT, p_name TEXT, p_desc TEXT, p_status TEXT, p_actor UUID
) RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE v_res JSON;
BEGIN
    UPDATE catalog.designations SET
        code = COALESCE(p_code, code),
        name = COALESCE(p_name, name),
        description = CASE WHEN p_desc IS NOT NULL THEN p_desc ELSE description END,
        status = COALESCE(p_status, status),
        updated_at = NOW(),
        updated_by = p_actor
    WHERE id = p_id
    RETURNING row_to_json(designations.*) INTO v_res;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Designation not found' USING ERRCODE = 'P0002';
    END IF;
    RETURN v_res;
END;
$$;






-- 6. Public RPC Wrappers
CREATE OR REPLACE FUNCTION public.rpc_create_department(p_code TEXT, p_name TEXT, p_desc TEXT, p_status TEXT, p_actor UUID) RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$ BEGIN RETURN catalog.create_department_impl(p_code, p_name, p_desc, p_status, p_actor); END; $$;
CREATE OR REPLACE FUNCTION public.rpc_update_department(p_id UUID, p_code TEXT, p_name TEXT, p_desc TEXT, p_status TEXT, p_actor UUID) RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$ BEGIN RETURN catalog.update_department_impl(p_id, p_code, p_name, p_desc, p_status, p_actor); END; $$;
CREATE OR REPLACE FUNCTION public.rpc_create_designation(p_code TEXT, p_name TEXT, p_desc TEXT, p_status TEXT, p_actor UUID) RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$ BEGIN RETURN catalog.create_designation_impl(p_code, p_name, p_desc, p_status, p_actor); END; $$;
CREATE OR REPLACE FUNCTION public.rpc_update_designation(p_id UUID, p_code TEXT, p_name TEXT, p_desc TEXT, p_status TEXT, p_actor UUID) RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$ BEGIN RETURN catalog.update_designation_impl(p_id, p_code, p_name, p_desc, p_status, p_actor); END; $$;












REVOKE EXECUTE ON FUNCTION catalog.create_department_impl(TEXT, TEXT, TEXT, TEXT, UUID) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION catalog.update_department_impl(UUID, TEXT, TEXT, TEXT, TEXT, UUID) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION catalog.create_designation_impl(TEXT, TEXT, TEXT, TEXT, UUID) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION catalog.update_designation_impl(UUID, TEXT, TEXT, TEXT, TEXT, UUID) FROM PUBLIC, anon, authenticated;

REVOKE EXECUTE ON FUNCTION public.rpc_create_department(TEXT, TEXT, TEXT, TEXT, UUID) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.rpc_update_department(UUID, TEXT, TEXT, TEXT, TEXT, UUID) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.rpc_create_designation(TEXT, TEXT, TEXT, TEXT, UUID) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.rpc_update_designation(UUID, TEXT, TEXT, TEXT, TEXT, UUID) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.rpc_create_department(TEXT, TEXT, TEXT, TEXT, UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.rpc_update_department(UUID, TEXT, TEXT, TEXT, TEXT, UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.rpc_create_designation(TEXT, TEXT, TEXT, TEXT, UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.rpc_update_designation(UUID, TEXT, TEXT, TEXT, TEXT, UUID) TO service_role;

COMMIT;
