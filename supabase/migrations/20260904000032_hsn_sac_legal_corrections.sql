-- Migration 20260904000032: HSN/SAC Legal Corrections
-- Source: ITC(HS) 2022, DGCIS, Kolkata
-- official_source: https://www.dgciskol.gov.in/Writereaddata/Downloads/ITC-HS_2022.pdf
-- source_reference fields listed in source_reference column below
DO $$
DECLARE
    v_india_id          UUID;
    v_target_id         UUID;
    v_other_id          UUID;
    v_updated_rows      INTEGER;
    v_hsn_count         INTEGER;
    v_sac_count         INTEGER;
    v_total_count       INTEGER;
    v_rls_enabled       BOOLEAN;
    v_force_rls         BOOLEAN;
    v_invoker           BOOLEAN;
    v_public_catalog    BOOLEAN;
    v_public_public     BOOLEAN;
    v_coverage_status   TEXT;
    v_final_desc        TEXT;
BEGIN
    -- 1. Resolve India via iso2='IN' — INTO STRICT asserts exactly one row.
    SELECT id INTO STRICT v_india_id FROM catalog.countries WHERE iso2 = 'IN';

    -- 2. Assert exactly one ACTIVE India HSN 52083110 with pre-correction description.
    SELECT id INTO STRICT v_target_id
    FROM catalog.hsn_sac
    WHERE country_id  = v_india_id
      AND code        = '52083110'
      AND code_type   = 'HSN'
      AND status      = 'ACTIVE';

    IF (SELECT description FROM catalog.hsn_sac WHERE id = v_target_id) <> 'SHIRTING FABRICS' THEN
        RAISE EXCEPTION 'ASSERTION FAILED: Pre-update description for 52083110 is not SHIRTING FABRICS.';
    END IF;

    -- 3. Assert exactly one ACTIVE India HSN 52083130.
    SELECT id INTO STRICT v_other_id
    FROM catalog.hsn_sac
    WHERE country_id  = v_india_id
      AND code        = '52083130'
      AND code_type   = 'HSN'
      AND status      = 'ACTIVE';

    IF (SELECT description FROM catalog.hsn_sac WHERE id = v_other_id) <> 'SHIRTING FABRICS' THEN
        RAISE EXCEPTION 'ASSERTION FAILED: Pre-update description for 52083130 is not SHIRTING FABRICS.';
    END IF;

    -- Execute the correction.
    UPDATE catalog.hsn_sac
    SET
        description      = 'Lungi',
        official_source  = 'https://www.dgciskol.gov.in/Writereaddata/Downloads/ITC-HS_2022.pdf',
        source_reference = 'SOURCE_EDITION=ITC(HS) 2022 | EFFECTIVE_FROM=2022-04-01 | PDF_SHA256=B55FAA6BF804D5531AE370313E75DBFA6246B96C7DBC26211836DE6CFE91386C | PDF_PHYSICAL_PAGE=364_OF_739 | PRINTED_PAGE=363 | LOCATOR=SECTION-XI/CHAPTER-52/5208/520831/52083110 | ADJACENT_VERIFICATION=52083130:Shirting fabrics | GST_DIRECTORY_BASE_SHA256=051108E31063F1EF0D6DFB005A622BCC848878FA2D94FAE51A73E67F8916871E | DGFT_24_2026_CROSSCHECK_SHA256=B7B53358E91B2DFE17AEF9DF1CC6C4F119DB6EF9C471917A001F8BBCB83E47D2'
    WHERE id = v_target_id;

    -- Assert exactly one row was updated.
    GET DIAGNOSTICS v_updated_rows = ROW_COUNT;
    IF v_updated_rows <> 1 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: Expected 1 updated row, got %.', v_updated_rows;
    END IF;

    -- Assert post-update description = 'Lungi'.
    SELECT description INTO v_final_desc FROM catalog.hsn_sac WHERE id = v_target_id;
    IF v_final_desc <> 'Lungi' THEN
        RAISE EXCEPTION 'ASSERTION FAILED: Post-update description is not Lungi.';
    END IF;

    -- Assert 52083130 is unchanged.
    IF (SELECT description FROM catalog.hsn_sac WHERE id = v_other_id) <> 'SHIRTING FABRICS' THEN
        RAISE EXCEPTION 'ASSERTION FAILED: 52083130 description changed unexpectedly.';
    END IF;

    -- 4a. Query and assert RLS=true and FORCE_RLS=true on catalog.hsn_sac.
    SELECT relrowsecurity, relforcerowsecurity
    INTO   v_rls_enabled, v_force_rls
    FROM   pg_class
    WHERE  oid = 'catalog.hsn_sac'::regclass;

    IF NOT v_rls_enabled THEN
        RAISE EXCEPTION 'ASSERTION FAILED: RLS is disabled on catalog.hsn_sac.';
    END IF;
    IF NOT v_force_rls THEN
        RAISE EXCEPTION 'ASSERTION FAILED: FORCE RLS is disabled on catalog.hsn_sac.';
    END IF;

    -- 4b. security_invoker using IS DISTINCT FROM TRUE (NULL cannot pass).
    SELECT ('security_invoker=true' = ANY(reloptions))
    INTO   v_invoker
    FROM   pg_class
    WHERE  oid = 'public.hsn_sac'::regclass;

    IF v_invoker IS DISTINCT FROM TRUE THEN
        RAISE EXCEPTION 'ASSERTION FAILED: public.hsn_sac is not security_invoker=true.';
    END IF;

    -- 5. service_role: SELECT=true; INSERT/UPDATE/DELETE=false on both objects.
    IF NOT has_table_privilege('service_role', 'catalog.hsn_sac', 'SELECT') THEN
        RAISE EXCEPTION 'ASSERTION FAILED: service_role lacks SELECT on catalog.hsn_sac.'; END IF;
    IF has_table_privilege('service_role', 'catalog.hsn_sac', 'INSERT') THEN
        RAISE EXCEPTION 'ASSERTION FAILED: service_role has INSERT on catalog.hsn_sac.'; END IF;
    IF has_table_privilege('service_role', 'catalog.hsn_sac', 'UPDATE') THEN
        RAISE EXCEPTION 'ASSERTION FAILED: service_role has UPDATE on catalog.hsn_sac.'; END IF;
    IF has_table_privilege('service_role', 'catalog.hsn_sac', 'DELETE') THEN
        RAISE EXCEPTION 'ASSERTION FAILED: service_role has DELETE on catalog.hsn_sac.'; END IF;

    IF NOT has_table_privilege('service_role', 'public.hsn_sac', 'SELECT') THEN
        RAISE EXCEPTION 'ASSERTION FAILED: service_role lacks SELECT on public.hsn_sac.'; END IF;
    IF has_table_privilege('service_role', 'public.hsn_sac', 'INSERT') THEN
        RAISE EXCEPTION 'ASSERTION FAILED: service_role has INSERT on public.hsn_sac.'; END IF;
    IF has_table_privilege('service_role', 'public.hsn_sac', 'UPDATE') THEN
        RAISE EXCEPTION 'ASSERTION FAILED: service_role has UPDATE on public.hsn_sac.'; END IF;
    IF has_table_privilege('service_role', 'public.hsn_sac', 'DELETE') THEN
        RAISE EXCEPTION 'ASSERTION FAILED: service_role has DELETE on public.hsn_sac.'; END IF;

    -- 6. anon: no privileges on either object.
    IF has_table_privilege('anon', 'catalog.hsn_sac', 'SELECT') THEN
        RAISE EXCEPTION 'ASSERTION FAILED: anon has SELECT on catalog.hsn_sac.'; END IF;
    IF has_table_privilege('anon', 'catalog.hsn_sac', 'INSERT') THEN
        RAISE EXCEPTION 'ASSERTION FAILED: anon has INSERT on catalog.hsn_sac.'; END IF;
    IF has_table_privilege('anon', 'catalog.hsn_sac', 'UPDATE') THEN
        RAISE EXCEPTION 'ASSERTION FAILED: anon has UPDATE on catalog.hsn_sac.'; END IF;
    IF has_table_privilege('anon', 'catalog.hsn_sac', 'DELETE') THEN
        RAISE EXCEPTION 'ASSERTION FAILED: anon has DELETE on catalog.hsn_sac.'; END IF;
    IF has_table_privilege('anon', 'public.hsn_sac', 'SELECT') THEN
        RAISE EXCEPTION 'ASSERTION FAILED: anon has SELECT on public.hsn_sac.'; END IF;
    IF has_table_privilege('anon', 'public.hsn_sac', 'INSERT') THEN
        RAISE EXCEPTION 'ASSERTION FAILED: anon has INSERT on public.hsn_sac.'; END IF;
    IF has_table_privilege('anon', 'public.hsn_sac', 'UPDATE') THEN
        RAISE EXCEPTION 'ASSERTION FAILED: anon has UPDATE on public.hsn_sac.'; END IF;
    IF has_table_privilege('anon', 'public.hsn_sac', 'DELETE') THEN
        RAISE EXCEPTION 'ASSERTION FAILED: anon has DELETE on public.hsn_sac.'; END IF;

    -- 7. authenticated: no privileges on either object.
    IF has_table_privilege('authenticated', 'catalog.hsn_sac', 'SELECT') THEN
        RAISE EXCEPTION 'ASSERTION FAILED: authenticated has SELECT on catalog.hsn_sac.'; END IF;
    IF has_table_privilege('authenticated', 'catalog.hsn_sac', 'INSERT') THEN
        RAISE EXCEPTION 'ASSERTION FAILED: authenticated has INSERT on catalog.hsn_sac.'; END IF;
    IF has_table_privilege('authenticated', 'catalog.hsn_sac', 'UPDATE') THEN
        RAISE EXCEPTION 'ASSERTION FAILED: authenticated has UPDATE on catalog.hsn_sac.'; END IF;
    IF has_table_privilege('authenticated', 'catalog.hsn_sac', 'DELETE') THEN
        RAISE EXCEPTION 'ASSERTION FAILED: authenticated has DELETE on catalog.hsn_sac.'; END IF;
    IF has_table_privilege('authenticated', 'public.hsn_sac', 'SELECT') THEN
        RAISE EXCEPTION 'ASSERTION FAILED: authenticated has SELECT on public.hsn_sac.'; END IF;
    IF has_table_privilege('authenticated', 'public.hsn_sac', 'INSERT') THEN
        RAISE EXCEPTION 'ASSERTION FAILED: authenticated has INSERT on public.hsn_sac.'; END IF;
    IF has_table_privilege('authenticated', 'public.hsn_sac', 'UPDATE') THEN
        RAISE EXCEPTION 'ASSERTION FAILED: authenticated has UPDATE on public.hsn_sac.'; END IF;
    IF has_table_privilege('authenticated', 'public.hsn_sac', 'DELETE') THEN
        RAISE EXCEPTION 'ASSERTION FAILED: authenticated has DELETE on public.hsn_sac.'; END IF;

    -- 8. PUBLIC ACL check via relacl/aclexplode (grantee OID 0 = PUBLIC).
    SELECT EXISTS (
        SELECT 1
        FROM   pg_class c, aclexplode(c.relacl) a
        WHERE  c.oid      = 'catalog.hsn_sac'::regclass
          AND  a.grantee  = 0
    ) INTO v_public_catalog;
    IF v_public_catalog THEN
        RAISE EXCEPTION 'ASSERTION FAILED: PUBLIC has ACL grants on catalog.hsn_sac.'; END IF;

    SELECT EXISTS (
        SELECT 1
        FROM   pg_class c, aclexplode(c.relacl) a
        WHERE  c.oid      = 'public.hsn_sac'::regclass
          AND  a.grantee  = 0
    ) INTO v_public_public;
    IF v_public_public THEN
        RAISE EXCEPTION 'ASSERTION FAILED: PUBLIC has ACL grants on public.hsn_sac.'; END IF;

    -- 9. India ACTIVE row counts scoped to India.
    SELECT count(*) INTO v_total_count
    FROM catalog.hsn_sac
    WHERE country_id = v_india_id AND status = 'ACTIVE';
    IF v_total_count <> 22607 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: India ACTIVE total is %, expected 22607.', v_total_count; END IF;

    SELECT count(*) INTO v_hsn_count
    FROM catalog.hsn_sac
    WHERE country_id = v_india_id AND code_type = 'HSN' AND status = 'ACTIVE';
    IF v_hsn_count <> 21928 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: India ACTIVE HSN is %, expected 21928.', v_hsn_count; END IF;

    SELECT count(*) INTO v_sac_count
    FROM catalog.hsn_sac
    WHERE country_id = v_india_id AND code_type = 'SAC' AND status = 'ACTIVE';
    IF v_sac_count <> 679 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: India ACTIVE SAC is %, expected 679.', v_sac_count; END IF;

    -- 10. Exact HSN/SAC country_tax_coverage row for India.
    --     INTO STRICT asserts exactly one matching coverage row.
    SELECT status INTO STRICT v_coverage_status
    FROM catalog.country_tax_coverage
    WHERE country_id = v_india_id;

    IF v_coverage_status IS DISTINCT FROM 'UNRESOLVED' THEN
        RAISE EXCEPTION 'ASSERTION FAILED: India coverage status is %, expected UNRESOLVED.', v_coverage_status;
    END IF;

    RAISE NOTICE 'REHEARSAL OK: 52083110=Lungi | 52083130=SHIRTING FABRICS | HSN=21928 | SAC=679 | TOTAL=22607 | RLS=true | FORCE_RLS=true | security_invoker=true | PUBLIC_ACL=none | coverage=UNRESOLVED';
END $$;
