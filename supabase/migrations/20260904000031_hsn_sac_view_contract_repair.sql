-- Migration 20260904000031: Repair public.hsn_sac view contract
-- Branch A: catalog.hsn_sac has effective_from/effective_to/heading;
--           public.hsn_sac view omitted them, breaking the API select.
-- This migration recreates the view with a complete explicit column list,
-- preserves security_invoker=true, and re-asserts all privilege/RLS invariants.

-- Drop and recreate (CREATE OR REPLACE cannot reorder/rename columns in a view).
DROP VIEW IF EXISTS public.hsn_sac;

CREATE VIEW public.hsn_sac
    WITH (security_invoker = true)
AS
SELECT
    id,
    code,
    code_type,
    description,
    chapter,
    heading,
    parent_code,
    goods_or_service,
    status,
    effective_from,
    effective_to,
    official_source,
    source_reference,
    country_id,
    created_at,
    classification_level,
    code_length,
    is_leaf
FROM catalog.hsn_sac;

-- Re-assert privilege contract: revoke all, grant service_role SELECT only.
REVOKE ALL ON public.hsn_sac FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON public.hsn_sac TO service_role;

-- Verify invariants inside the same transaction.
DO $$
DECLARE
    v_invoker        BOOLEAN;
    v_rls_enabled    BOOLEAN;
    v_force_rls      BOOLEAN;
    v_has_ef         BOOLEAN;
    v_has_heading    BOOLEAN;
BEGIN
    -- security_invoker IS DISTINCT FROM TRUE catches NULL.
    SELECT ('security_invoker=true' = ANY(reloptions))
    INTO   v_invoker
    FROM   pg_class WHERE oid = 'public.hsn_sac'::regclass;
    IF v_invoker IS DISTINCT FROM TRUE THEN
        RAISE EXCEPTION 'ASSERTION FAILED: public.hsn_sac is not security_invoker.';
    END IF;

    -- RLS and FORCE RLS on the base table must be intact.
    SELECT relrowsecurity, relforcerowsecurity
    INTO   v_rls_enabled, v_force_rls
    FROM   pg_class WHERE oid = 'catalog.hsn_sac'::regclass;
    IF NOT v_rls_enabled THEN
        RAISE EXCEPTION 'ASSERTION FAILED: RLS disabled on catalog.hsn_sac.'; END IF;
    IF NOT v_force_rls THEN
        RAISE EXCEPTION 'ASSERTION FAILED: FORCE RLS disabled on catalog.hsn_sac.'; END IF;

    -- View must now expose effective_from and heading.
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'hsn_sac'
          AND column_name = 'effective_from'
    ) INTO v_has_ef;
    IF NOT v_has_ef THEN
        RAISE EXCEPTION 'ASSERTION FAILED: public.hsn_sac still missing effective_from.'; END IF;

    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'hsn_sac'
          AND column_name = 'heading'
    ) INTO v_has_heading;
    IF NOT v_has_heading THEN
        RAISE EXCEPTION 'ASSERTION FAILED: public.hsn_sac still missing heading.'; END IF;

    -- Privilege checks.
    IF has_table_privilege('anon',          'public.hsn_sac', 'SELECT') THEN
        RAISE EXCEPTION 'ASSERTION FAILED: anon has SELECT on public.hsn_sac.'; END IF;
    IF has_table_privilege('authenticated', 'public.hsn_sac', 'SELECT') THEN
        RAISE EXCEPTION 'ASSERTION FAILED: authenticated has SELECT on public.hsn_sac.'; END IF;
    IF NOT has_table_privilege('service_role', 'public.hsn_sac', 'SELECT') THEN
        RAISE EXCEPTION 'ASSERTION FAILED: service_role lacks SELECT on public.hsn_sac.'; END IF;
    IF has_table_privilege('service_role', 'public.hsn_sac', 'INSERT') THEN
        RAISE EXCEPTION 'ASSERTION FAILED: service_role has INSERT on public.hsn_sac.'; END IF;
    IF has_table_privilege('service_role', 'public.hsn_sac', 'UPDATE') THEN
        RAISE EXCEPTION 'ASSERTION FAILED: service_role has UPDATE on public.hsn_sac.'; END IF;
    IF has_table_privilege('service_role', 'public.hsn_sac', 'DELETE') THEN
        RAISE EXCEPTION 'ASSERTION FAILED: service_role has DELETE on public.hsn_sac.'; END IF;

    RAISE NOTICE 'VIEW CONTRACT OK: effective_from=present heading=present security_invoker=true RLS=true FORCE_RLS=true service_role=SELECT-only anon/authenticated=none';
END $$;

-- Signal PostgREST to reload its schema cache.
NOTIFY pgrst, 'reload schema';
