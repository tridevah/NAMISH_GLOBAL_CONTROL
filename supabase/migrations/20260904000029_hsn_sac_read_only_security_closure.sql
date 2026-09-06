-- Migration 20260904000029: HSN/SAC Read-Only Security Closure
-- 1. Revoke every privilege from PUBLIC, anon, authenticated and service_role
REVOKE ALL PRIVILEGES ON catalog.hsn_sac FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON public.hsn_sac FROM PUBLIC, anon, authenticated, service_role;

-- 2. Grant service_role SELECT only on both objects
GRANT SELECT ON catalog.hsn_sac TO service_role;
GRANT SELECT ON public.hsn_sac TO service_role;

-- 3. Assertions
DO $$
DECLARE
    roles_to_check text[] := ARRAY['anon', 'authenticated'];
    r text;
    v_priv_granted boolean;
BEGIN
    -- Assert anon/authenticated have no privileges
    FOREACH r IN ARRAY roles_to_check LOOP
        SELECT EXISTS (
            SELECT 1 FROM information_schema.role_table_grants 
            WHERE table_schema = 'catalog' AND table_name = 'hsn_sac' AND grantee = r
        ) INTO v_priv_granted;
        IF v_priv_granted THEN
            RAISE EXCEPTION 'ASSERTION FAILED: % has privileges on catalog.hsn_sac', r;
        END IF;
    END LOOP;

    -- Assert service_role has SELECT but not INSERT/UPDATE/DELETE
    IF NOT has_table_privilege('service_role', 'catalog.hsn_sac', 'SELECT') THEN
        RAISE EXCEPTION 'ASSERTION FAILED: service_role lacks SELECT on catalog.hsn_sac';
    END IF;
    IF has_table_privilege('service_role', 'catalog.hsn_sac', 'INSERT') THEN
        RAISE EXCEPTION 'ASSERTION FAILED: service_role has INSERT on catalog.hsn_sac';
    END IF;
    IF has_table_privilege('service_role', 'catalog.hsn_sac', 'UPDATE') THEN
        RAISE EXCEPTION 'ASSERTION FAILED: service_role has UPDATE on catalog.hsn_sac';
    END IF;
    IF has_table_privilege('service_role', 'catalog.hsn_sac', 'DELETE') THEN
        RAISE EXCEPTION 'ASSERTION FAILED: service_role has DELETE on catalog.hsn_sac';
    END IF;
END $$;
