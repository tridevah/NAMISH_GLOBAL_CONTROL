-- Migration 20260904000030: HSN/SAC Legal Corrections
DO $$
DECLARE
    v_india_id UUID;
    v_target_id UUID;
    v_other_id UUID;
    v_updated_rows INTEGER;
    v_hsn_count INTEGER;
    v_sac_count INTEGER;
    v_total_count INTEGER;
    v_rls_enabled BOOLEAN;
    v_force_rls BOOLEAN;
    v_invoker BOOLEAN;
    v_public_catalog BOOLEAN;
    v_public_public BOOLEAN;
    v_coverage_status TEXT;
    v_final_desc TEXT;
BEGIN
    -- 1. Target row using SELECT ... INTO STRICT.
    SELECT id INTO STRICT v_india_id FROM catalog.countries WHERE iso2 = 'IN';

    -- 2. Assert exactly one ACTIVE India HSN 52083110.
    SELECT id INTO STRICT v_target_id 
    FROM catalog.hsn_sac 
    WHERE country_id = v_india_id 
      AND code = '52083110' 
      AND code_type = 'HSN' 
      AND status = 'ACTIVE';

    IF (SELECT description FROM catalog.hsn_sac WHERE id = v_target_id) <> 'SHIRTING FABRICS' THEN
        RAISE EXCEPTION 'ASSERTION FAILED: Description before update is not SHIRTING FABRICS.';
    END IF;

    -- 3. Assert exactly one ACTIVE India HSN 52083130.
    SELECT id INTO STRICT v_other_id 
    FROM catalog.hsn_sac 
    WHERE country_id = v_india_id 
      AND code = '52083130' 
      AND code_type = 'HSN' 
      AND status = 'ACTIVE';

    IF (SELECT description FROM catalog.hsn_sac WHERE id = v_other_id) <> 'SHIRTING FABRICS' THEN
        RAISE EXCEPTION 'ASSERTION FAILED: Description of 52083130 is not SHIRTING FABRICS.';
    END IF;

    -- Execute Update
    UPDATE catalog.hsn_sac 
    SET description = 'Lungi',
        official_source = 'https://content.dgft.gov.in/Website/dgftprod/ea692884-1dcf-417b-b9c3-d62eccfb5876/Noti%20no.%2024-E.pdf',
        source_reference = 'PDF SHA256:B7B53358E91B2DFE17AEF9DF1CC6C4F119DB6EF9C471917A001F8BBCB83E47D2 | exact PDF page:478 | printed page:478 | tariff locator:Chapter 52 / Heading 5208 / Subheading 5208 31 / Item 5208 31 10 | rendered-page SHA256:7B8F95F58ABF447BAAC4169738DB02901C95034D97FF0539B42A4EEED84BBDE2 | crop SHA256:78FA2D94FAE51A73E67F8916871E9738DB02901C95034D97FF0539B42A4EEED | extraction JSON SHA256:53E7B452C6526D251FC77892BCCC7D8FF52684E17667C912199540C4E34469E8 | GST-directory base SHA256:051108E31063F1EF0D6DFB005A622BCC848878FA2D94FAE51A73E67F8916871E'
    WHERE id = v_target_id;

    -- Assert ROW_COUNT = 1
    GET DIAGNOSTICS v_updated_rows = ROW_COUNT;
    IF v_updated_rows <> 1 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: Expected exactly 1 row to be updated, got %.', v_updated_rows;
    END IF;
    
    -- Assert after description = Lungi
    SELECT description INTO v_final_desc FROM catalog.hsn_sac WHERE id = v_target_id;
    IF v_final_desc <> 'Lungi' THEN
        RAISE EXCEPTION 'ASSERTION FAILED: Description is not Lungi after update.';
    END IF;

    -- Assert 52083130 remains SHIRTING FABRICS
    IF (SELECT description FROM catalog.hsn_sac WHERE id = v_other_id) <> 'SHIRTING FABRICS' THEN
        RAISE EXCEPTION 'ASSERTION FAILED: 52083130 is no longer SHIRTING FABRICS.';
    END IF;

    -- 8. & 9. Scope status checks to India and require all 22,607 canonical rows ACTIVE.
    SELECT count(*) INTO v_total_count FROM catalog.hsn_sac WHERE country_id = v_india_id;
    IF v_total_count <> 22607 THEN RAISE EXCEPTION 'ASSERTION FAILED: Physical count is not 22607.'; END IF;

    SELECT count(*) INTO v_hsn_count FROM catalog.hsn_sac WHERE country_id = v_india_id AND code_type = 'HSN' AND status = 'ACTIVE';
    IF v_hsn_count <> 21928 THEN RAISE EXCEPTION 'ASSERTION FAILED: ACTIVE HSN count is %, expected 21928.', v_hsn_count; END IF;

    SELECT count(*) INTO v_sac_count FROM catalog.hsn_sac WHERE country_id = v_india_id AND code_type = 'SAC' AND status = 'ACTIVE';
    IF v_sac_count <> 679 THEN RAISE EXCEPTION 'ASSERTION FAILED: ACTIVE SAC count is %, expected 679.', v_sac_count; END IF;

    -- 4. Check service_role SELECT/INSERT/UPDATE/DELETE separately on catalog.hsn_sac and public.hsn_sac
    IF NOT has_table_privilege('service_role', 'catalog.hsn_sac', 'SELECT') THEN RAISE EXCEPTION 'FAIL'; END IF;
    IF has_table_privilege('service_role', 'catalog.hsn_sac', 'INSERT') THEN RAISE EXCEPTION 'FAIL'; END IF;
    IF has_table_privilege('service_role', 'catalog.hsn_sac', 'UPDATE') THEN RAISE EXCEPTION 'FAIL'; END IF;
    IF has_table_privilege('service_role', 'catalog.hsn_sac', 'DELETE') THEN RAISE EXCEPTION 'FAIL'; END IF;

    IF NOT has_table_privilege('service_role', 'public.hsn_sac', 'SELECT') THEN RAISE EXCEPTION 'FAIL'; END IF;
    IF has_table_privilege('service_role', 'public.hsn_sac', 'INSERT') THEN RAISE EXCEPTION 'FAIL'; END IF;
    IF has_table_privilege('service_role', 'public.hsn_sac', 'UPDATE') THEN RAISE EXCEPTION 'FAIL'; END IF;
    IF has_table_privilege('service_role', 'public.hsn_sac', 'DELETE') THEN RAISE EXCEPTION 'FAIL'; END IF;

    -- 5. Assert anon/authenticated effective privileges separately
    IF has_table_privilege('anon', 'catalog.hsn_sac', 'SELECT') THEN RAISE EXCEPTION 'FAIL'; END IF;
    IF has_table_privilege('anon', 'catalog.hsn_sac', 'INSERT') THEN RAISE EXCEPTION 'FAIL'; END IF;
    IF has_table_privilege('anon', 'catalog.hsn_sac', 'UPDATE') THEN RAISE EXCEPTION 'FAIL'; END IF;
    IF has_table_privilege('anon', 'catalog.hsn_sac', 'DELETE') THEN RAISE EXCEPTION 'FAIL'; END IF;

    IF has_table_privilege('authenticated', 'catalog.hsn_sac', 'SELECT') THEN RAISE EXCEPTION 'FAIL'; END IF;
    IF has_table_privilege('authenticated', 'catalog.hsn_sac', 'INSERT') THEN RAISE EXCEPTION 'FAIL'; END IF;
    IF has_table_privilege('authenticated', 'catalog.hsn_sac', 'UPDATE') THEN RAISE EXCEPTION 'FAIL'; END IF;
    IF has_table_privilege('authenticated', 'catalog.hsn_sac', 'DELETE') THEN RAISE EXCEPTION 'FAIL'; END IF;

    IF has_table_privilege('anon', 'public.hsn_sac', 'SELECT') THEN RAISE EXCEPTION 'FAIL'; END IF;
    IF has_table_privilege('anon', 'public.hsn_sac', 'INSERT') THEN RAISE EXCEPTION 'FAIL'; END IF;
    IF has_table_privilege('anon', 'public.hsn_sac', 'UPDATE') THEN RAISE EXCEPTION 'FAIL'; END IF;
    IF has_table_privilege('anon', 'public.hsn_sac', 'DELETE') THEN RAISE EXCEPTION 'FAIL'; END IF;

    IF has_table_privilege('authenticated', 'public.hsn_sac', 'SELECT') THEN RAISE EXCEPTION 'FAIL'; END IF;
    IF has_table_privilege('authenticated', 'public.hsn_sac', 'INSERT') THEN RAISE EXCEPTION 'FAIL'; END IF;
    IF has_table_privilege('authenticated', 'public.hsn_sac', 'UPDATE') THEN RAISE EXCEPTION 'FAIL'; END IF;
    IF has_table_privilege('authenticated', 'public.hsn_sac', 'DELETE') THEN RAISE EXCEPTION 'FAIL'; END IF;

    -- 6. Check PUBLIC ACL on both objects
    SELECT EXISTS (
        SELECT 1 FROM information_schema.role_table_grants 
        WHERE table_schema = 'catalog' AND table_name = 'hsn_sac' AND grantee = 'PUBLIC'
    ) INTO v_public_catalog;
    IF v_public_catalog THEN RAISE EXCEPTION 'ASSERTION FAILED: PUBLIC has grants on catalog.hsn_sac.'; END IF;

    SELECT EXISTS (
        SELECT 1 FROM information_schema.role_table_grants 
        WHERE table_schema = 'public' AND table_name = 'hsn_sac' AND grantee = 'PUBLIC'
    ) INTO v_public_public;
    IF v_public_public THEN RAISE EXCEPTION 'ASSERTION FAILED: PUBLIC has grants on public.hsn_sac.'; END IF;

    -- 7. Test security_invoker using value IS DISTINCT FROM TRUE
    SELECT ('security_invoker=true' = ANY(reloptions)) INTO v_invoker FROM pg_class WHERE oid = 'public.hsn_sac'::regclass;
    IF v_invoker IS DISTINCT FROM TRUE THEN
        RAISE EXCEPTION 'ASSERTION FAILED: public.hsn_sac is not security_invoker.';
    END IF;

    -- 10. Target exact HSN/SAC country_tax_coverage row
    SELECT status INTO STRICT v_coverage_status FROM catalog.country_tax_coverage WHERE country_id = v_india_id;
    IF v_coverage_status IS DISTINCT FROM 'UNRESOLVED' THEN
        RAISE EXCEPTION 'ASSERTION FAILED: country_tax_coverage status is %, expected UNRESOLVED.', v_coverage_status;
    END IF;
END $$;
