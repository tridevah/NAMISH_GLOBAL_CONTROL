BEGIN ISOLATION LEVEL SERIALIZABLE;
ALTER TABLE catalog.geography_units DISABLE TRIGGER USER;

DO $$
DECLARE
    v_release_id uuid;
    state_level_id uuid;
    district_level_id uuid;
    subdistrict_level_id uuid;
    india_id uuid;
BEGIN
    SELECT id INTO v_release_id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R16';
    SELECT id INTO india_id FROM catalog.countries WHERE iso3 = 'IND';
    
    SELECT id INTO state_level_id FROM catalog.geography_levels WHERE level_key = 'STATE_UT';
    SELECT id INTO district_level_id FROM catalog.geography_levels WHERE level_key = 'DISTRICT';
    SELECT id INTO subdistrict_level_id FROM catalog.geography_levels WHERE level_key = 'SUB_DISTRICT';
    
    -- 1. Insert STATES
    INSERT INTO catalog.geography_units (country_id, geography_level_id, official_code, official_name, display_name, status)
    SELECT india_id, state_level_id, 
           (raw_data->>'TITLE')::text, 
           (raw_data->>'TITLE')::text, 
           (raw_data->>'TITLE')::text, 
           'ACTIVE'
    FROM staging.geography_imports
    WHERE release_id = v_release_id AND entity_type = 'STATE'
    ON CONFLICT (country_id, geography_level_id, official_code) DO NOTHING;

    -- 2. Insert DISTRICTS
    INSERT INTO catalog.geography_units (country_id, geography_level_id, official_code, official_name, display_name, status)
    SELECT india_id, district_level_id, 
           (raw_data->>'district code')::text, 
           raw_data->>'district name', 
           raw_data->>'district name', 
           'ACTIVE'
    FROM staging.geography_imports
    WHERE release_id = v_release_id AND entity_type = 'DISTRICT'
    ON CONFLICT (country_id, geography_level_id, official_code) DO NOTHING;
    
    -- 3. Insert SUB_DISTRICTS
    INSERT INTO catalog.geography_units (country_id, geography_level_id, official_code, official_name, display_name, status)
    SELECT india_id, subdistrict_level_id, 
           COALESCE(raw_data->>'sub-district code', raw_data->>'subdistrict code')::text, 
           COALESCE(raw_data->>'sub-district name (in english)', raw_data->>'subdistrict name (in english)'), 
           COALESCE(raw_data->>'sub-district name (in english)', raw_data->>'subdistrict name (in english)'), 
           'ACTIVE'
    FROM staging.geography_imports
    WHERE release_id = v_release_id AND entity_type = 'SUB_DISTRICT'
    ON CONFLICT (country_id, geography_level_id, official_code) DO NOTHING;

    RAISE NOTICE 'geography_units=%', (SELECT count(*) FROM catalog.geography_units);
END;
$$;

ROLLBACK;
