-- Migration 20260904000034: GST rate security and grant repair
-- Problem: 000033 issued REVOKE ALL on public views but never granted
--          service_role SELECT on the *base* catalog tables.
--          Result: service_role = 0 privileges on catalog.gst_rate_master
--                                  and catalog.gst_rate_applications.
-- Fix:
--   1. Enable RLS + FORCE RLS on both catalog tables.
--   2. Add a permissive service_role-only SELECT policy on each.
--   3. REVOKE any remaining PUBLIC/anon/authenticated access on both
--      catalog tables and both public views.
--   4. GRANT SELECT to service_role on all four objects.
--   5. Keep INSERT/UPDATE/DELETE = false for service_role.
--   6. Reload PostgREST schema cache.
-- No HSN/SAC, Geography, Currency or HSN/SAC row DML.
-- India country_tax_coverage remains UNRESOLVED.

-- ─── catalog.gst_rate_master ──────────────────────────────────────────────────
ALTER TABLE catalog.gst_rate_master ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog.gst_rate_master FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS gst_rate_master_service_role_select ON catalog.gst_rate_master;
CREATE POLICY gst_rate_master_service_role_select
    ON catalog.gst_rate_master
    FOR SELECT
    TO service_role
    USING (true);

REVOKE ALL ON catalog.gst_rate_master FROM PUBLIC, anon, authenticated;
GRANT  SELECT ON catalog.gst_rate_master TO service_role;

-- ─── catalog.gst_rate_applications ───────────────────────────────────────────
ALTER TABLE catalog.gst_rate_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog.gst_rate_applications FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS gst_rate_applications_service_role_select ON catalog.gst_rate_applications;
CREATE POLICY gst_rate_applications_service_role_select
    ON catalog.gst_rate_applications
    FOR SELECT
    TO service_role
    USING (true);

REVOKE ALL ON catalog.gst_rate_applications FROM PUBLIC, anon, authenticated;
GRANT  SELECT ON catalog.gst_rate_applications TO service_role;

-- ─── public views (re-assert — already set in 000033, repeating is safe) ──────
REVOKE ALL ON public.gst_rate_master       FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON public.gst_rate_applications FROM PUBLIC, anon, authenticated, service_role;
GRANT  SELECT ON public.gst_rate_master       TO service_role;
GRANT  SELECT ON public.gst_rate_applications TO service_role;

-- ─── Assertions ───────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_rls_m     BOOLEAN; v_frls_m    BOOLEAN;
    v_rls_a     BOOLEAN; v_frls_a    BOOLEAN;
    v_sr_sel_m  BOOLEAN; v_sr_ins_m  BOOLEAN;
    v_sr_sel_a  BOOLEAN; v_sr_ins_a  BOOLEAN;
    v_anon_m    BOOLEAN; v_anon_a    BOOLEAN;
    v_si_m      BOOLEAN; v_si_a      BOOLEAN;
    v_coverage  TEXT;
    v_total     INTEGER; v_current   INTEGER;
    v_tran      INTEGER; v_comp      INTEGER; v_hist INTEGER;
    v_in_id     UUID;
BEGIN
    SELECT id INTO STRICT v_in_id FROM catalog.countries WHERE iso2 = 'IN';

    -- RLS
    SELECT relrowsecurity, relforcerowsecurity INTO v_rls_m, v_frls_m
    FROM pg_class WHERE oid = 'catalog.gst_rate_master'::regclass;
    IF NOT v_rls_m  THEN RAISE EXCEPTION 'ASSERT FAIL: RLS disabled on catalog.gst_rate_master.'; END IF;
    IF NOT v_frls_m THEN RAISE EXCEPTION 'ASSERT FAIL: FORCE RLS disabled on catalog.gst_rate_master.'; END IF;

    SELECT relrowsecurity, relforcerowsecurity INTO v_rls_a, v_frls_a
    FROM pg_class WHERE oid = 'catalog.gst_rate_applications'::regclass;
    IF NOT v_rls_a  THEN RAISE EXCEPTION 'ASSERT FAIL: RLS disabled on catalog.gst_rate_applications.'; END IF;
    IF NOT v_frls_a THEN RAISE EXCEPTION 'ASSERT FAIL: FORCE RLS disabled on catalog.gst_rate_applications.'; END IF;

    -- service_role grants on catalog tables
    v_sr_sel_m := has_table_privilege('service_role','catalog.gst_rate_master','SELECT');
    v_sr_ins_m := has_table_privilege('service_role','catalog.gst_rate_master','INSERT');
    IF NOT v_sr_sel_m THEN RAISE EXCEPTION 'ASSERT FAIL: service_role lacks SELECT on catalog.gst_rate_master.'; END IF;
    IF v_sr_ins_m     THEN RAISE EXCEPTION 'ASSERT FAIL: service_role has INSERT on catalog.gst_rate_master.'; END IF;

    v_sr_sel_a := has_table_privilege('service_role','catalog.gst_rate_applications','SELECT');
    v_sr_ins_a := has_table_privilege('service_role','catalog.gst_rate_applications','INSERT');
    IF NOT v_sr_sel_a THEN RAISE EXCEPTION 'ASSERT FAIL: service_role lacks SELECT on catalog.gst_rate_applications.'; END IF;
    IF v_sr_ins_a     THEN RAISE EXCEPTION 'ASSERT FAIL: service_role has INSERT on catalog.gst_rate_applications.'; END IF;

    -- anon has nothing
    v_anon_m := has_table_privilege('anon','catalog.gst_rate_master','SELECT');
    v_anon_a := has_table_privilege('anon','catalog.gst_rate_applications','SELECT');
    IF v_anon_m THEN RAISE EXCEPTION 'ASSERT FAIL: anon has SELECT on catalog.gst_rate_master.'; END IF;
    IF v_anon_a THEN RAISE EXCEPTION 'ASSERT FAIL: anon has SELECT on catalog.gst_rate_applications.'; END IF;

    -- public views: security_invoker
    SELECT ('security_invoker=true' = ANY(reloptions)) INTO v_si_m
    FROM pg_class WHERE oid = 'public.gst_rate_master'::regclass;
    IF v_si_m IS DISTINCT FROM TRUE THEN
        RAISE EXCEPTION 'ASSERT FAIL: public.gst_rate_master is not security_invoker.';
    END IF;

    SELECT ('security_invoker=true' = ANY(reloptions)) INTO v_si_a
    FROM pg_class WHERE oid = 'public.gst_rate_applications'::regclass;
    IF v_si_a IS DISTINCT FROM TRUE THEN
        RAISE EXCEPTION 'ASSERT FAIL: public.gst_rate_applications is not security_invoker.';
    END IF;

    -- Row counts from 000033 still intact
    SELECT count(*) INTO v_total   FROM catalog.gst_rate_master WHERE country_id = v_in_id;
    SELECT count(*) INTO v_current FROM catalog.gst_rate_master WHERE country_id = v_in_id AND is_current;
    SELECT count(*) INTO v_tran    FROM catalog.gst_rate_master WHERE country_id = v_in_id AND usage_scope='TRANSACTION_RATE' AND is_current;
    SELECT count(*) INTO v_comp    FROM catalog.gst_rate_master WHERE country_id = v_in_id AND usage_scope='TAXPAYER_SCHEME';
    SELECT count(*) INTO v_hist    FROM catalog.gst_rate_master WHERE country_id = v_in_id AND usage_scope='HISTORICAL';

    IF v_total   <> 14 THEN RAISE EXCEPTION 'ASSERT FAIL: total=%, expected 14.', v_total; END IF;
    IF v_current <> 13 THEN RAISE EXCEPTION 'ASSERT FAIL: current=%, expected 13.', v_current; END IF;
    IF v_tran    <> 10 THEN RAISE EXCEPTION 'ASSERT FAIL: TRANSACTION_RATE=%, expected 10.', v_tran; END IF;
    IF v_comp    <>  3 THEN RAISE EXCEPTION 'ASSERT FAIL: TAXPAYER_SCHEME=%, expected 3.', v_comp; END IF;
    IF v_hist    <>  1 THEN RAISE EXCEPTION 'ASSERT FAIL: HISTORICAL=%, expected 1.', v_hist; END IF;

    -- Coverage
    SELECT status INTO STRICT v_coverage FROM catalog.country_tax_coverage WHERE country_id = v_in_id;
    IF v_coverage IS DISTINCT FROM 'UNRESOLVED' THEN
        RAISE EXCEPTION 'ASSERT FAIL: India coverage=%, expected UNRESOLVED.', v_coverage;
    END IF;

    -- HSN/SAC untouched
    IF (SELECT count(*) FROM catalog.hsn_sac WHERE country_id=v_in_id AND status='ACTIVE' AND code_type='HSN') <> 21928 THEN
        RAISE EXCEPTION 'ASSERT FAIL: HSN count changed.';
    END IF;
    IF (SELECT count(*) FROM catalog.hsn_sac WHERE country_id=v_in_id AND status='ACTIVE' AND code_type='SAC') <> 679 THEN
        RAISE EXCEPTION 'ASSERT FAIL: SAC count changed.';
    END IF;

    RAISE NOTICE 'ALL ASSERTIONS PASSED: RLS=true FORCE_RLS=true | service_role SELECT=true INSERT=false | anon=none | security_invoker=true | rows total=14 current=13 TRANSACTION=10 COMPOSITION=3 HISTORICAL=1 | coverage=UNRESOLVED | HSN=21928 SAC=679';
END $$;

NOTIFY pgrst, 'reload schema';
