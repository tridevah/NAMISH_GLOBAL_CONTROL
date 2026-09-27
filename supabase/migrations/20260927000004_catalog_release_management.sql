-- Migration: Release Management RPCs
-- Scope:     GC database

BEGIN;
SET LOCAL search_path = '';

CREATE OR REPLACE FUNCTION catalog.create_business_release(p_version TEXT, p_include_cleanup BOOLEAN)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = catalog, pg_temp
AS $$
DECLARE
    v_release_id UUID := gen_random_uuid();
BEGIN
    INSERT INTO catalog.catalog_releases 
        (id, version, status, hsn_sac_intentionally_empty, tax_profiles_intentionally_empty, units_intentionally_empty)
    VALUES 
        (v_release_id, p_version, 'DRAFT', false, false, false);

    -- 1. HSN_SAC
    INSERT INTO catalog.catalog_release_items (release_id, item_type, item_id, payload)
    SELECT v_release_id, 'HSN_SAC', id,
        jsonb_build_object(
            'id', id, 'code', code, 'type', goods_or_service,
            'description', description, 'category', COALESCE(chapter, heading)
        )
    FROM catalog.hsn_sac;

    -- 2. UNIT
    INSERT INTO catalog.catalog_release_items (release_id, item_type, item_id, payload)
    SELECT v_release_id, 'UNIT', id,
        jsonb_build_object(
            'id', id, 'code', COALESCE(standard_code, canonical_code),
            'canonical_code', canonical_code,
            'name', name,
            'is_business', is_business,
            'business_name', business_name,
            'short_name', short_name,
            'status', CASE WHEN is_business THEN status WHEN p_include_cleanup THEN 'INACTIVE' ELSE status END
        )
    FROM catalog.measurement_units
    WHERE is_business = true OR p_include_cleanup = true;

    -- 3. TAX_PROFILE
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

    RETURN v_release_id;
END;
$$;

REVOKE ALL ON FUNCTION catalog.create_business_release(TEXT, BOOLEAN) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION catalog.create_business_release(TEXT, BOOLEAN) TO service_role;
ALTER FUNCTION catalog.create_business_release(TEXT, BOOLEAN) OWNER TO postgres;

CREATE OR REPLACE FUNCTION catalog.publish_draft_release(p_release_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = catalog, pg_temp
AS $$
BEGIN
    UPDATE catalog.catalog_releases SET status = 'PUBLISHED' WHERE id = p_release_id AND status = 'DRAFT';
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Release % not found or not in DRAFT status', p_release_id;
    END IF;
    RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION catalog.publish_draft_release(UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION catalog.publish_draft_release(UUID) TO service_role;
ALTER FUNCTION catalog.publish_draft_release(UUID) OWNER TO postgres;

COMMIT;
