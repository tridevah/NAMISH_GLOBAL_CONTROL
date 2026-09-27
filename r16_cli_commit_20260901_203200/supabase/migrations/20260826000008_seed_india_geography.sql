-- Migration 000009: Seed India Geography & Public Gateway RPCs

-- ============================================================================
-- 1. PUBLIC RPC GATEWAY FOR GEOGRAPHY (SECURITY DEFINER)
-- ============================================================================

-- Function to get all countries
CREATE OR REPLACE FUNCTION public.rpc_get_countries()
RETURNS SETOF catalog.countries AS $$
BEGIN
    RETURN QUERY SELECT * FROM catalog.countries ORDER BY display_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path TO pg_catalog;

REVOKE ALL ON FUNCTION public.rpc_get_countries() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_get_countries() TO service_role;

-- Function to create a country
CREATE OR REPLACE FUNCTION public.rpc_create_country(
    p_iso2 TEXT,
    p_iso3 TEXT,
    p_numeric_code TEXT,
    p_official_name TEXT,
    p_display_name TEXT,
    p_default_currency_code TEXT,
    p_staff_id pg_catalog.uuid
) RETURNS catalog.countries AS $$
DECLARE
    v_record catalog.countries;
BEGIN
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, created_by)
    VALUES (p_iso2, p_iso3, p_numeric_code, p_official_name, p_display_name, p_default_currency_code, p_staff_id)
    RETURNING * INTO v_record;
    RETURN v_record;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path TO pg_catalog;

REVOKE ALL ON FUNCTION public.rpc_create_country FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_create_country TO service_role;

-- Function to update a country
CREATE OR REPLACE FUNCTION public.rpc_update_country(
    p_id pg_catalog.uuid,
    p_official_name TEXT,
    p_display_name TEXT,
    p_default_currency_code TEXT,
    p_status TEXT,
    p_staff_id pg_catalog.uuid
) RETURNS catalog.countries AS $$
DECLARE
    v_record catalog.countries;
BEGIN
    UPDATE catalog.countries 
    SET official_name = p_official_name,
        display_name = p_display_name,
        default_currency_code = p_default_currency_code,
        status = p_status,
        updated_by = p_staff_id,
        updated_at = pg_catalog.now()
    WHERE id = p_id
    RETURNING * INTO v_record;
    RETURN v_record;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path TO pg_catalog;

REVOKE ALL ON FUNCTION public.rpc_update_country FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_update_country TO service_role;


-- Function to get levels
CREATE OR REPLACE FUNCTION public.rpc_get_levels(p_country_id pg_catalog.uuid)
RETURNS SETOF catalog.geography_levels AS $$
BEGIN
    RETURN QUERY SELECT * FROM catalog.geography_levels WHERE country_id = p_country_id ORDER BY level_number;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path TO pg_catalog;

REVOKE ALL ON FUNCTION public.rpc_get_levels FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_get_levels TO service_role;


-- ============================================================================
-- 2. SEED INDIA GEOGRAPHY
-- ============================================================================
DO $$
DECLARE
    v_india_id pg_catalog.uuid := pg_catalog.md5('country_IND')::pg_catalog.uuid;
    v_level1_id pg_catalog.uuid := pg_catalog.md5('geo_level_IND_1')::pg_catalog.uuid;
    v_level2_id pg_catalog.uuid := pg_catalog.md5('geo_level_IND_2')::pg_catalog.uuid;
    v_level3_id pg_catalog.uuid := pg_catalog.md5('geo_level_IND_3')::pg_catalog.uuid;
    v_level4_id pg_catalog.uuid := pg_catalog.md5('geo_level_IND_4')::pg_catalog.uuid;
BEGIN
    -- 1. Insert India
    INSERT INTO catalog.countries (id, iso2, iso3, numeric_code, official_name, display_name, default_currency_code)
    VALUES (v_india_id, 'IN', 'IND', '356', 'Republic of India', 'India', 'INR')
    ON CONFLICT (id) DO UPDATE SET 
        iso2 = EXCLUDED.iso2,
        iso3 = EXCLUDED.iso3,
        numeric_code = EXCLUDED.numeric_code,
        official_name = EXCLUDED.official_name,
        display_name = EXCLUDED.display_name,
        default_currency_code = EXCLUDED.default_currency_code;

    -- 2. Insert Levels
    INSERT INTO catalog.geography_levels (id, country_id, level_number, level_key, display_label)
    VALUES 
        (v_level1_id, v_india_id, 1, 'STATE_UT', 'State / Union Territory'),
        (v_level2_id, v_india_id, 2, 'DISTRICT', 'District'),
        (v_level3_id, v_india_id, 3, 'SUB_DISTRICT', 'Sub-District / Tehsil / Block'),
        (v_level4_id, v_india_id, 4, 'LOCALITY', 'City / Town / Village')
    ON CONFLICT (id) DO UPDATE SET
        level_number = EXCLUDED.level_number,
        level_key = EXCLUDED.level_key,
        display_label = EXCLUDED.display_label;

    -- 3. Insert States/UTs (Level 1)
    -- Using a temporary table to cleanly iterate and insert with deterministic UUIDs
    CREATE TEMP TABLE tmp_states (code TEXT, name TEXT, type TEXT);
    
    INSERT INTO tmp_states (code, name, type) VALUES
    ('35', 'Andaman And Nicobar Islands', 'UT'),
    ('28', 'Andhra Pradesh', 'State'),
    ('12', 'Arunachal Pradesh', 'State'),
    ('18', 'Assam', 'State'),
    ('10', 'Bihar', 'State'),
    ('4', 'Chandigarh', 'UT'),
    ('22', 'Chhattisgarh', 'State'),
    ('7', 'Delhi', 'UT'),
    ('30', 'Goa', 'State'),
    ('24', 'Gujarat', 'State'),
    ('6', 'Haryana', 'State'),
    ('2', 'Himachal Pradesh', 'State'),
    ('1', 'Jammu And Kashmir', 'UT'),
    ('20', 'Jharkhand', 'State'),
    ('29', 'Karnataka', 'State'),
    ('32', 'Kerala', 'State'),
    ('37', 'Ladakh', 'UT'),
    ('31', 'Lakshadweep', 'UT'),
    ('23', 'Madhya Pradesh', 'State'),
    ('27', 'Maharashtra', 'State'),
    ('14', 'Manipur', 'State'),
    ('17', 'Meghalaya', 'State'),
    ('15', 'Mizoram', 'State'),
    ('13', 'Nagaland', 'State'),
    ('21', 'Odisha', 'State'),
    ('34', 'Puducherry', 'UT'),
    ('3', 'Punjab', 'State'),
    ('8', 'Rajasthan', 'State'),
    ('11', 'Sikkim', 'State'),
    ('33', 'Tamil Nadu', 'State'),
    ('36', 'Telangana', 'State'),
    ('38', 'The Dadra And Nagar Haveli And Daman And Diu', 'UT'),
    ('16', ' ????????', 'State'), -- Fixing the Hindi encoding issue safely by using English Name:
    ('16', 'Tripura', 'State'),
    ('5', 'Uttarakhand', 'State'),
    ('9', 'Uttar Pradesh', 'State'),
    ('19', 'West Bengal', 'State');

    -- Note: Removed the duplicate row for Tripura above inside the loop
    DELETE FROM tmp_states WHERE name = ' ????????';

    INSERT INTO catalog.geography_units (
        id, country_id, geography_level_id, parent_geography_unit_id, 
        official_code, official_name, display_name
    )
    SELECT 
        pg_catalog.md5('geo_unit_IND_LGD_' || code)::pg_catalog.uuid,
        v_india_id,
        v_level1_id,
        NULL,
        code,
        name,
        name
    FROM tmp_states
    ON CONFLICT (id) DO UPDATE SET
        official_code = EXCLUDED.official_code,
        official_name = EXCLUDED.official_name,
        display_name = EXCLUDED.display_name;

    DROP TABLE tmp_states;
END;
$$;
