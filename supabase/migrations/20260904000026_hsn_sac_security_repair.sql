-- Migration 20260904000026: Security repair for catalog.hsn_sac
-- 
-- RAW EVIDENCE (from pg_class + pg_roles queries 2026-09-05):
--   rls_enabled: false    (disabled by 000010)
--   force_rls:   true     (set by earlier migration)
--   table_owner: postgres
--   postgres.rolbypassrls = true → migration runner bypasses RLS
--   service_role.rolbypassrls = true → admin client bypasses RLS
--   anon: no grants on catalog.hsn_sac
--   authenticated: no grants on catalog.hsn_sac
--   public.hsn_sac view: SECURITY DEFINER (default) — must be SECURITY INVOKER
--
-- WITHDRAWN CLAIM: "RLS silently blocked INSERTs"
--   Evidence: postgres has rolbypassrls=true, so RLS could not block its INSERTs.
--   Actual cause of migration failures: nested BEGIN/COMMIT in DO-block migrations
--   000009/000010 prevented proper ledger recording, causing repeated re-application.
--
-- THIS MIGRATION:
--   1. Re-enables RLS on catalog.hsn_sac
--   2. Creates a read-only SELECT policy for service_role (admin API path only)
--   3. Recreates public.hsn_sac view with SECURITY INVOKER = true
--   4. Explicitly revokes INSERT/UPDATE/DELETE from PUBLIC, anon, authenticated
--   5. Preserves SELECT-only for service_role (already granted via table ownership chain)

-- Step 1: Re-enable RLS
ALTER TABLE catalog.hsn_sac ENABLE ROW LEVEL SECURITY;

-- Step 2: No client-side write access — explicit revoke from all non-owner roles
-- (anon and authenticated already have no grants, but make it explicit)
REVOKE INSERT, UPDATE, DELETE ON catalog.hsn_sac FROM PUBLIC;
REVOKE INSERT, UPDATE, DELETE ON catalog.hsn_sac FROM anon;
REVOKE INSERT, UPDATE, DELETE ON catalog.hsn_sac FROM authenticated;

-- Step 3: Create read-only RLS policy for service_role (used by Next.js admin client)
-- postgres and service_role have rolbypassrls=true so they bypass this policy anyway,
-- but we define it for documentation and to allow future authenticated reads if needed.
CREATE POLICY hsn_sac_service_role_select
  ON catalog.hsn_sac
  FOR SELECT
  TO service_role
  USING (true);

-- Step 4: Recreate public.hsn_sac view as SECURITY INVOKER
-- This ensures the view runs with the caller's privileges, not the definer's.
-- Since anon/authenticated have no grants on catalog.hsn_sac, they cannot read
-- through this view without explicit grants.
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
  parent_code,
  goods_or_service,
  status,
  classification_level,
  code_length,
  is_leaf,
  official_source,
  source_reference,
  country_id,
  created_at
FROM catalog.hsn_sac;

-- Revoke write on the view too
REVOKE INSERT, UPDATE, DELETE ON public.hsn_sac FROM PUBLIC;
REVOKE INSERT, UPDATE, DELETE ON public.hsn_sac FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.hsn_sac FROM authenticated;

-- Grant SELECT on view to service_role only (admin client path)
GRANT SELECT ON public.hsn_sac TO service_role;

-- Step 5: Assertions
DO $$
DECLARE
  v_rls_on  BOOLEAN;
  v_force   BOOLEAN;
BEGIN
  SELECT relrowsecurity, relforcerowsecurity
  INTO v_rls_on, v_force
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'catalog' AND c.relname = 'hsn_sac';

  IF NOT v_rls_on THEN
    RAISE EXCEPTION 'ASSERTION FAILED: RLS must be enabled on catalog.hsn_sac';
  END IF;

  RAISE NOTICE 'Security repair assertions passed: rls_enabled=%, force_rls=%', v_rls_on, v_force;
END $$;
