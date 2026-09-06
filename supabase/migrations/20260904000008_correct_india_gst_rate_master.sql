-- Migration 20260904000008: Correct India GST Rate Master
BEGIN;

DO $$
DECLARE
    v_country_id UUID;
    v_updated_count INT;
    v_total_updated INT := 0;
BEGIN
    SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'IN';

    -- 1. Update 0%
    UPDATE catalog.gst_rate_master
    SET category = 'NIL',
        rate_name = 'Nil Rated',
        is_current = TRUE,
        effective_from = '2025-09-22',
        notification_number = '10/2025-Central Tax (Rate)',
        official_source = 'https://egazette.gov.in/WriteReadData/2025/266210.pdf',
        notes = NULL
    WHERE country_id = v_country_id AND rate_percent = 0.00 AND category = 'NIL';
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    IF v_updated_count <> 1 THEN RAISE EXCEPTION 'Update failed for 0%%'; END IF;
    v_total_updated := v_total_updated + v_updated_count;

    -- 2. Update 0.25%
    UPDATE catalog.gst_rate_master
    SET category = 'SPECIAL',
        rate_name = 'Special Rate 0.25%',
        is_current = TRUE,
        effective_from = '2025-09-22',
        notification_number = '09/2025-Central Tax (Rate)',
        official_source = 'https://egazette.gov.in/WriteReadData/2025/266209.pdf',
        notes = NULL
    WHERE country_id = v_country_id AND rate_percent = 0.25 AND category = 'SPECIAL';
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    IF v_updated_count <> 1 THEN RAISE EXCEPTION 'Update failed for 0.25%%'; END IF;
    v_total_updated := v_total_updated + v_updated_count;

    -- 3. Update 1.5%
    UPDATE catalog.gst_rate_master
    SET category = 'SPECIAL',
        rate_name = 'Special Rate 1.5%',
        is_current = TRUE,
        effective_from = '2025-09-22',
        notification_number = '09/2025-Central Tax (Rate)',
        official_source = 'https://egazette.gov.in/WriteReadData/2025/266209.pdf',
        notes = NULL
    WHERE country_id = v_country_id AND rate_percent = 1.50 AND category = 'SPECIAL';
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    IF v_updated_count <> 1 THEN RAISE EXCEPTION 'Update failed for 1.5%%'; END IF;
    v_total_updated := v_total_updated + v_updated_count;

    -- 4. Update 3%
    UPDATE catalog.gst_rate_master
    SET category = 'SPECIAL',
        rate_name = 'Special Rate 3%',
        is_current = TRUE,
        effective_from = '2025-09-22',
        notification_number = '09/2025-Central Tax (Rate)',
        official_source = 'https://egazette.gov.in/WriteReadData/2025/266209.pdf',
        notes = NULL
    WHERE country_id = v_country_id AND rate_percent = 3.00 AND category = 'STANDARD';
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    IF v_updated_count <> 1 THEN RAISE EXCEPTION 'Update failed for 3%%'; END IF;
    v_total_updated := v_total_updated + v_updated_count;

    -- 5. Update 5%
    UPDATE catalog.gst_rate_master
    SET category = 'STANDARD',
        rate_name = 'Standard Rate 5%',
        is_current = TRUE,
        effective_from = '2025-09-22',
        notification_number = '09/2025-Central Tax (Rate)',
        official_source = 'https://egazette.gov.in/WriteReadData/2025/266209.pdf',
        notes = NULL
    WHERE country_id = v_country_id AND rate_percent = 5.00 AND category = 'STANDARD';
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    IF v_updated_count <> 1 THEN RAISE EXCEPTION 'Update failed for 5%%'; END IF;
    v_total_updated := v_total_updated + v_updated_count;

    -- 6. Update 12%
    UPDATE catalog.gst_rate_master
    SET category = 'SPECIAL',
        rate_name = 'Special Rate 12% (Specified Supplies Only)',
        is_current = TRUE,
        effective_from = '2025-09-22',
        notification_number = '14/2025-Central Tax (Rate)',
        official_source = 'https://egazette.gov.in/WriteReadData/2025/266219.pdf',
        notes = NULL
    WHERE country_id = v_country_id AND rate_percent = 12.00 AND category = 'STANDARD';
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    IF v_updated_count <> 1 THEN RAISE EXCEPTION 'Update failed for 12%%'; END IF;
    v_total_updated := v_total_updated + v_updated_count;

    -- 7. Update 18%
    UPDATE catalog.gst_rate_master
    SET category = 'STANDARD',
        rate_name = 'Standard Rate 18%',
        is_current = TRUE,
        effective_from = '2025-09-22',
        notification_number = '09/2025-Central Tax (Rate)',
        official_source = 'https://egazette.gov.in/WriteReadData/2025/266209.pdf',
        notes = NULL
    WHERE country_id = v_country_id AND rate_percent = 18.00 AND category = 'STANDARD';
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    IF v_updated_count <> 1 THEN RAISE EXCEPTION 'Update failed for 18%%'; END IF;
    v_total_updated := v_total_updated + v_updated_count;

    -- 8. Update 40%
    UPDATE catalog.gst_rate_master
    SET category = 'SPECIAL',
        rate_name = 'Special Demerit Rate 40%',
        is_current = TRUE,
        effective_from = '2025-09-22',
        notification_number = '09/2025-Central Tax (Rate)',
        official_source = 'https://egazette.gov.in/WriteReadData/2025/266209.pdf',
        notes = 'Source chain must also reference 19/2025-Central Tax (Rate) effective 2026-02-01 (https://egazette.gov.in/WriteReadData/2025/268978.pdf) and 01/2026-Central Tax (Rate) effective 2026-05-01 (https://egazette.gov.in/WriteReadData/2026/272190.pdf)'
    WHERE country_id = v_country_id AND rate_percent = 40.00 AND category = 'STANDARD';
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    IF v_updated_count <> 1 THEN RAISE EXCEPTION 'Update failed for 40%%'; END IF;
    v_total_updated := v_total_updated + v_updated_count;

    -- 9. Update 28%
    UPDATE catalog.gst_rate_master
    SET category = 'HISTORICAL',
        rate_name = 'Standard Rate 28% (Historical)',
        is_current = FALSE,
        status = 'INACTIVE',
        effective_to = '2026-01-31',
        notification_number = '19/2025-Central Tax (Rate)',
        official_source = NULL,
        notes = 'Stopped being current from 2026-02-01'
    WHERE country_id = v_country_id AND rate_percent = 28.00 AND category = 'HISTORICAL';
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    IF v_updated_count <> 1 THEN RAISE EXCEPTION 'Update failed for 28%%'; END IF;
    v_total_updated := v_total_updated + v_updated_count;

    -- 10. Update Composition 1%
    UPDATE catalog.gst_rate_master
    SET category = 'COMPOSITION',
        rate_name = 'Composition Rate 1%',
        is_current = TRUE,
        notes = 'Taxpayer scheme, not a product or invoice-line rate.'
    WHERE country_id = v_country_id AND rate_percent = 1.00 AND category = 'COMPOSITION';
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    IF v_updated_count <> 1 THEN RAISE EXCEPTION 'Update failed for 1%%'; END IF;
    v_total_updated := v_total_updated + v_updated_count;

    -- 11. Update Composition 5%
    UPDATE catalog.gst_rate_master
    SET category = 'COMPOSITION',
        rate_name = 'Composition Rate 5%',
        is_current = TRUE,
        notes = 'Taxpayer scheme, not a product or invoice-line rate.'
    WHERE country_id = v_country_id AND rate_percent = 5.00 AND category = 'COMPOSITION';
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    IF v_updated_count <> 1 THEN RAISE EXCEPTION 'Update failed for Comp 5%%'; END IF;
    v_total_updated := v_total_updated + v_updated_count;

    -- 12. Update Composition 6%
    UPDATE catalog.gst_rate_master
    SET category = 'COMPOSITION',
        rate_name = 'Composition Rate 6%',
        is_current = TRUE,
        notes = 'Taxpayer scheme, not a product or invoice-line rate.'
    WHERE country_id = v_country_id AND rate_percent = 6.00 AND category = 'COMPOSITION';
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    IF v_updated_count <> 1 THEN RAISE EXCEPTION 'Update failed for Comp 6%%'; END IF;
    v_total_updated := v_total_updated + v_updated_count;

    -- Total check
    IF v_total_updated <> 12 THEN 
        RAISE EXCEPTION 'Total updated rows % is not exactly 12', v_total_updated;
    END IF;

    -- Standard counts verification
    DECLARE
        v_standard_count INT;
        v_special_count INT;
    BEGIN
        SELECT COUNT(*) INTO v_standard_count FROM catalog.gst_rate_master WHERE category = 'STANDARD' AND country_id = v_country_id;
        IF v_standard_count <> 2 THEN RAISE EXCEPTION 'STANDARD count is %, expected 2', v_standard_count; END IF;

        SELECT COUNT(*) INTO v_special_count FROM catalog.gst_rate_master WHERE category = 'SPECIAL' AND country_id = v_country_id;
        IF v_special_count <> 5 THEN RAISE EXCEPTION 'SPECIAL count is %, expected 5', v_special_count; END IF;
    END;
END $$;

COMMIT;
