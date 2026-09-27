DO $$
DECLARE
    v_high_water BIGINT := 4;
    v_locked RECORD;
    v_current_seq BIGINT;
    v_is_called BOOLEAN;
    v_release_id UUID := gen_random_uuid();
BEGIN
    SELECT * INTO v_locked 
    FROM integration.catalog_sync_control 
    WHERE contract_key = 'AGGREGATE_V1' 
    FOR UPDATE NOWAIT;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Control row AGGREGATE_V1 is absent.';
    END IF;

    SELECT last_value, is_called INTO v_current_seq, v_is_called 
    FROM catalog.release_seq;

    IF v_current_seq < v_high_water THEN
        PERFORM setval('catalog.release_seq', v_high_water, true);
    END IF;

    INSERT INTO catalog.catalog_releases 
        (id, version, status, hsn_sac_intentionally_empty, tax_profiles_intentionally_empty, units_intentionally_empty)
    VALUES 
        (v_release_id, 'v8.0.0', 'DRAFT', false, false, false);

    INSERT INTO catalog.catalog_release_items (item_id, release_id, item_type, payload)
    SELECT id, v_release_id, 'HSN_SAC', 
        jsonb_build_object(
            'id', id, 'code', code, 'type', type,
            'description', description, 'category', category
        )
    FROM public.hsn_sac
    ON CONFLICT (item_id) DO UPDATE SET release_id = EXCLUDED.release_id, payload = EXCLUDED.payload;

    INSERT INTO catalog.catalog_release_items (item_id, release_id, item_type, payload)
    SELECT id, v_release_id, 'UNIT', 
        jsonb_build_object(
            'id', id, 'code', code,
            'canonical_code', COALESCE(canonical_code, code),
            'name', COALESCE(name, code),
            'is_business', is_business,
            'business_name', business_name,
            'short_name', COALESCE(short_name, code),
            'status', status
        )
    FROM public.measurement_units
    ON CONFLICT (item_id) DO UPDATE SET release_id = EXCLUDED.release_id, payload = EXCLUDED.payload;

    INSERT INTO catalog.catalog_release_items (item_id, release_id, item_type, payload)
    SELECT id, v_release_id, 'TAX_PROFILE', 
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
    FROM public.gst_rate_master
    ON CONFLICT (item_id) DO UPDATE SET release_id = EXCLUDED.release_id, payload = EXCLUDED.payload;

    UPDATE catalog.catalog_releases SET status = 'PUBLISHED' WHERE id = v_release_id;
    
    RAISE NOTICE 'RELEASE_ID_GENERATED: %', v_release_id;
END $$;
