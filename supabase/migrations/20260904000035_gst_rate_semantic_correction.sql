-- Migration 20260904000035: GST Rate Semantic Correction
-- 1. IN_GST_1_5: set effective_display_percent = 1.50 (statutory rate, not the 1% on-gross)
--    The 1% effective-on-gross figure belongs only to the REAL_ESTATE_AFFORDABLE_EFFECTIVE_1
--    application row; the master rate card should carry the statutory combined rate.
-- 2. Set 0.25%, 3%, 40% to CONTEXT_ONLY (0.10%, 7.5%, 12% are already CONTEXT_ONLY).
-- 3. Assert REAL_ESTATE_AFFORDABLE_EFFECTIVE_1 application unchanged.
-- 4. Assert GENERAL visibility = exactly {IN_GST_0, IN_GST_5, IN_GST_18}.
-- 5. Assert all counts preserved: 14 total / 13 current / 10 TRANSACTION / 3 COMPOSITION / 1 HISTORICAL / 11 applications.
-- No HSN/SAC, Geography, Currency, NAMISH_ERP DML.
-- India country_tax_coverage remains UNRESOLVED.

DO $$
DECLARE
    v_in_id UUID;
    v_app_val_factor  NUMERIC;
    v_app_eff         NUMERIC;
    v_app_stat        TEXT;
    v_app_vis         TEXT;
    v_total    INTEGER; v_current  INTEGER;
    v_tran     INTEGER; v_comp     INTEGER; v_hist INTEGER;
    v_apps     INTEGER;
    v_general_count INTEGER;
    v_coverage TEXT;
    rec RECORD;
BEGIN
    SELECT id INTO STRICT v_in_id FROM catalog.countries WHERE iso2 = 'IN';

    -- ── 1. Update IN_GST_1_5 ─────────────────────────────────────────────────
    UPDATE catalog.gst_rate_master SET
        statutory_rate_percent    = 1.50,
        effective_display_percent = 1.50,
        erp_visibility            = 'CONTEXT_ONLY'
    WHERE country_id = v_in_id AND rate_code = 'IN_GST_1_5';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'UPDATE FAILED: rate_code IN_GST_1_5 not found.';
    END IF;

    -- ── 2. Set 0.25% to CONTEXT_ONLY ─────────────────────────────────────────
    UPDATE catalog.gst_rate_master SET erp_visibility = 'CONTEXT_ONLY'
    WHERE country_id = v_in_id AND rate_code = 'IN_GST_0_25';
    IF NOT FOUND THEN RAISE EXCEPTION 'UPDATE FAILED: IN_GST_0_25 not found.'; END IF;

    -- ── 3. Set 3% to CONTEXT_ONLY ────────────────────────────────────────────
    UPDATE catalog.gst_rate_master SET erp_visibility = 'CONTEXT_ONLY'
    WHERE country_id = v_in_id AND rate_code = 'IN_GST_3';
    IF NOT FOUND THEN RAISE EXCEPTION 'UPDATE FAILED: IN_GST_3 not found.'; END IF;

    -- ── 4. Set 40% to CONTEXT_ONLY ───────────────────────────────────────────
    UPDATE catalog.gst_rate_master SET erp_visibility = 'CONTEXT_ONLY'
    WHERE country_id = v_in_id AND rate_code = 'IN_GST_40';
    IF NOT FOUND THEN RAISE EXCEPTION 'UPDATE FAILED: IN_GST_40 not found.'; END IF;

    -- ── 5. Verify CONTEXT_ONLY set for all 7 required transaction rates ───────
    FOR rec IN
        SELECT rate_code, erp_visibility FROM catalog.gst_rate_master
        WHERE country_id = v_in_id
          AND rate_code IN ('IN_GST_0_10','IN_GST_0_25','IN_GST_1_5','IN_GST_3','IN_GST_7_5','IN_GST_12','IN_GST_40')
    LOOP
        IF rec.erp_visibility <> 'CONTEXT_ONLY' THEN
            RAISE EXCEPTION 'ASSERT FAIL: % has erp_visibility=%, expected CONTEXT_ONLY.', rec.rate_code, rec.erp_visibility;
        END IF;
    END LOOP;

    -- ── 6. Verify GENERAL visibility = exactly {IN_GST_0, IN_GST_5, IN_GST_18} ─
    SELECT count(*) INTO v_general_count
    FROM catalog.gst_rate_master
    WHERE country_id = v_in_id
      AND usage_scope = 'TRANSACTION_RATE'
      AND erp_visibility = 'GENERAL';

    IF v_general_count <> 3 THEN
        RAISE EXCEPTION 'ASSERT FAIL: GENERAL TRANSACTION_RATE count=%, expected exactly 3 (0%%, 5%%, 18%%).', v_general_count;
    END IF;

    -- Confirm the 3 are exactly the right ones
    IF NOT EXISTS (SELECT 1 FROM catalog.gst_rate_master WHERE country_id=v_in_id AND rate_code='IN_GST_0'  AND erp_visibility='GENERAL') THEN
        RAISE EXCEPTION 'ASSERT FAIL: IN_GST_0 (0%%) not GENERAL.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM catalog.gst_rate_master WHERE country_id=v_in_id AND rate_code='IN_GST_5'  AND erp_visibility='GENERAL') THEN
        RAISE EXCEPTION 'ASSERT FAIL: IN_GST_5 (5%%) not GENERAL.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM catalog.gst_rate_master WHERE country_id=v_in_id AND rate_code='IN_GST_18' AND erp_visibility='GENERAL') THEN
        RAISE EXCEPTION 'ASSERT FAIL: IN_GST_18 (18%%) not GENERAL.';
    END IF;

    -- ── 7. Assert REAL_ESTATE_AFFORDABLE_EFFECTIVE_1 application unchanged ────
    SELECT valuation_factor, effective_display_percent, erp_visibility
    INTO   v_app_val_factor, v_app_eff, v_app_vis
    FROM   catalog.gst_rate_applications
    WHERE  country_id = v_in_id AND application_code = 'REAL_ESTATE_AFFORDABLE_EFFECTIVE_1';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'ASSERT FAIL: REAL_ESTATE_AFFORDABLE_EFFECTIVE_1 not found.';
    END IF;
    IF round(v_app_val_factor, 4) <> round(0.666667, 4) THEN
        RAISE EXCEPTION 'ASSERT FAIL: REAL_ESTATE_AFFORDABLE_EFFECTIVE_1 valuation_factor=%, expected ~0.6667.', v_app_val_factor;
    END IF;
    IF v_app_eff <> 1.00 THEN
        RAISE EXCEPTION 'ASSERT FAIL: REAL_ESTATE_AFFORDABLE_EFFECTIVE_1 effective_display_percent=%, expected 1.00.', v_app_eff;
    END IF;
    IF v_app_vis <> 'CONTEXT_ONLY' THEN
        RAISE EXCEPTION 'ASSERT FAIL: REAL_ESTATE_AFFORDABLE_EFFECTIVE_1 erp_visibility=%, expected CONTEXT_ONLY.', v_app_vis;
    END IF;

    -- Also verify base_rate_code still points to IN_GST_1_5
    IF NOT EXISTS (
        SELECT 1 FROM catalog.gst_rate_applications
        WHERE country_id = v_in_id
          AND application_code = 'REAL_ESTATE_AFFORDABLE_EFFECTIVE_1'
          AND base_rate_code = 'IN_GST_1_5'
    ) THEN
        RAISE EXCEPTION 'ASSERT FAIL: REAL_ESTATE_AFFORDABLE_EFFECTIVE_1 base_rate_code not IN_GST_1_5.';
    END IF;

    -- ── 8. Row-count invariants ───────────────────────────────────────────────
    SELECT count(*) INTO v_total   FROM catalog.gst_rate_master WHERE country_id = v_in_id;
    SELECT count(*) INTO v_current FROM catalog.gst_rate_master WHERE country_id = v_in_id AND is_current;
    SELECT count(*) INTO v_tran    FROM catalog.gst_rate_master WHERE country_id = v_in_id AND usage_scope='TRANSACTION_RATE' AND is_current;
    SELECT count(*) INTO v_comp    FROM catalog.gst_rate_master WHERE country_id = v_in_id AND usage_scope='TAXPAYER_SCHEME';
    SELECT count(*) INTO v_hist    FROM catalog.gst_rate_master WHERE country_id = v_in_id AND usage_scope='HISTORICAL';
    SELECT count(*) INTO v_apps    FROM catalog.gst_rate_applications WHERE country_id = v_in_id;

    IF v_total   <> 14 THEN RAISE EXCEPTION 'ASSERT FAIL: total=%, expected 14.', v_total; END IF;
    IF v_current <> 13 THEN RAISE EXCEPTION 'ASSERT FAIL: current=%, expected 13.', v_current; END IF;
    IF v_tran    <> 10 THEN RAISE EXCEPTION 'ASSERT FAIL: TRANSACTION_RATE=%, expected 10.', v_tran; END IF;
    IF v_comp    <>  3 THEN RAISE EXCEPTION 'ASSERT FAIL: TAXPAYER_SCHEME=%, expected 3.', v_comp; END IF;
    IF v_hist    <>  1 THEN RAISE EXCEPTION 'ASSERT FAIL: HISTORICAL=%, expected 1.', v_hist; END IF;
    IF v_apps    <> 11 THEN RAISE EXCEPTION 'ASSERT FAIL: applications=%, expected 11.', v_apps; END IF;

    -- ── 9. HSN/SAC untouched ─────────────────────────────────────────────────
    IF (SELECT count(*) FROM catalog.hsn_sac WHERE country_id=v_in_id AND status='ACTIVE' AND code_type='HSN') <> 21928 THEN
        RAISE EXCEPTION 'ASSERT FAIL: HSN count changed.';
    END IF;
    IF (SELECT count(*) FROM catalog.hsn_sac WHERE country_id=v_in_id AND status='ACTIVE' AND code_type='SAC') <> 679 THEN
        RAISE EXCEPTION 'ASSERT FAIL: SAC count changed.';
    END IF;

    -- ── 10. Coverage unchanged ────────────────────────────────────────────────
    SELECT status INTO STRICT v_coverage FROM catalog.country_tax_coverage WHERE country_id = v_in_id;
    IF v_coverage IS DISTINCT FROM 'UNRESOLVED' THEN
        RAISE EXCEPTION 'ASSERT FAIL: India coverage=%, expected UNRESOLVED.', v_coverage;
    END IF;

    RAISE NOTICE 'ALL ASSERTIONS PASSED: IN_GST_1_5 eff=1.50 | 0.25/3/40 → CONTEXT_ONLY | GENERAL={0%%,5%%,18%%} | REAL_ESTATE_AFFORDABLE_EFFECTIVE_1 unchanged (eff=1.00 val=0.6667) | counts 14/13/10/3/1/11 | HSN=21928 SAC=679 | coverage=UNRESOLVED';
END $$;

NOTIFY pgrst, 'reload schema';
