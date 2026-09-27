DO $$
DECLARE
    v_erp_high_water BIGINT := 4; 
    v_locked RECORD;
    v_current_seq BIGINT;
    v_is_called BOOLEAN;
    v_gc_max BIGINT;
    v_outbox_max BIGINT;
    v_target_seq BIGINT;
    v_release_id UUID := gen_random_uuid();
    v_hsn_count INT;
    v_unit_count INT;
    v_tax_count INT;
BEGIN
    SELECT * INTO v_locked 
    FROM catalog.catalog_sync_control 
    WHERE contract_key = 'AGGREGATE_V1' 
    FOR UPDATE NOWAIT;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Control row AGGREGATE_V1 is absent.';
    END IF;

    INSERT INTO catalog.catalog_releases 
        (id, version, status, hsn_sac_intentionally_empty, tax_profiles_intentionally_empty, units_intentionally_empty)
    VALUES 
        (v_release_id, 'v8.0.0', 'DRAFT', false, false, false);

    INSERT INTO catalog.catalog_release_items (release_id, item_type, item_id, payload)
    SELECT v_release_id, 'HSN_SAC', id,
        jsonb_build_object(
            'id', id, 'code', code, 'type', goods_or_service,
            'description', description, 'category', COALESCE(chapter, heading)
        )
    FROM catalog.hsn_sac;

    INSERT INTO catalog.catalog_release_items (release_id, item_type, item_id, payload)
    SELECT v_release_id, 'UNIT', id,
        jsonb_build_object(
            'id', id, 'code', COALESCE(standard_code, canonical_code),
            'canonical_code', canonical_code,
            'name', name,
            'is_business', is_business,
            'business_name', business_name,
            'short_name', short_name,
            'status', status
        )
    FROM catalog.measurement_units;

    INSERT INTO catalog.catalog_release_items (release_id, item_type, item_id, payload)
    SELECT v_release_id, 'TAX_PROFILE', id,
        jsonb_build_object(
            'id', id, 'country_id', country_id,
            'name', rate_name, 'rate', rate_percent,
            'category', category,
            'statutory_rate_percent', statutory_rate_percent,
            'effective_display_percent', effective_display_percent,
            'erp_visibility', erp_visibility, 'valuation_basis', valuation_basis,
            'itc_policy', itc_policy, 'conditions', COALESCE(conditions, '{}'::jsonb),
            'usage_scope', usage_scope, 'status', status,
            'effective_from', effective_from, 'effective_to', effective_to,
            'is_current', is_current
        )
    FROM public.gst_rate_master;

    SELECT COUNT(*) INTO v_hsn_count FROM catalog.catalog_release_items WHERE release_id = v_release_id AND item_type = 'HSN_SAC';
    SELECT COUNT(*) INTO v_unit_count FROM catalog.catalog_release_items WHERE release_id = v_release_id AND item_type = 'UNIT';
    SELECT COUNT(*) INTO v_tax_count FROM catalog.catalog_release_items WHERE release_id = v_release_id AND item_type = 'TAX_PROFILE';

    IF v_hsn_count = 0 OR v_unit_count = 0 OR v_tax_count != 15 THEN
        RAISE EXCEPTION 'Validation failed: HSN (%), UNIT (%), TAX (%). Tax must be exactly 15.', v_hsn_count, v_unit_count, v_tax_count;
    END IF;

    SELECT last_value, is_called INTO v_current_seq, v_is_called 
    FROM catalog.release_seq;

    SELECT COALESCE(MAX(release_sequence), 0) INTO v_gc_max 
    FROM catalog.catalog_releases;

    SELECT COALESCE(MAX((payload->>'release_sequence')::BIGINT), 0) INTO v_outbox_max 
    FROM integration.outbox_events
    WHERE event_type = 'catalog.release.published';
    
    v_target_seq := GREATEST(v_erp_high_water, v_gc_max, v_outbox_max);

    IF v_current_seq < v_target_seq THEN
        PERFORM setval('catalog.release_seq', v_target_seq, true);
    ELSIF v_current_seq = v_target_seq AND v_is_called = false THEN
        PERFORM setval('catalog.release_seq', v_target_seq, true);
    END IF;

    UPDATE catalog.catalog_releases SET status = 'PUBLISHED' WHERE id = v_release_id;
    
    RAISE NOTICE 'RELEASE_ID_GENERATED: %', v_release_id;
END $$;
