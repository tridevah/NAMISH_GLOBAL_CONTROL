BEGIN ISOLATION LEVEL SERIALIZABLE;

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
    
    -- 1. Insert new blocks
    INSERT INTO catalog.development_blocks (id, official_code, official_name, status, district_id)
    SELECT gen_random_uuid(), s.block_code::text, s.block_name, 'ACTIVE', NULL
    FROM (
        SELECT DISTINCT (COALESCE(raw_data->>'block code', raw_data->>'development block code'))::int AS block_code,
               COALESCE(raw_data->>'block name', raw_data->>'development block name (in english)') AS block_name
        FROM staging.geography_imports
        WHERE release_id = v_release_id AND entity_type = 'BLOCK'
          AND COALESCE(raw_data->>'block code', raw_data->>'development block code') IS NOT NULL
    ) s
    LEFT JOIN catalog.development_blocks e ON s.block_code::text = e.official_code
    WHERE e.official_code IS NULL;
    
    -- 2. Insert new relationships (multi-district and normal)
    INSERT INTO catalog.block_districts (block_id, district_id, source_release_id)
    SELECT b.id, d.id, v_release_id
    FROM (
        SELECT DISTINCT (COALESCE(raw_data->>'block code', raw_data->>'development block code'))::int AS block_code,
               (COALESCE(raw_data->>'district code', raw_data->>'district code'))::int AS district_code
        FROM staging.geography_imports
        WHERE release_id = v_release_id AND entity_type = 'BLOCK'
          AND raw_data->>'district code' IS NOT NULL
    ) r
    JOIN catalog.development_blocks b ON r.block_code::text = b.official_code
    JOIN catalog.geography_units d ON r.district_code::text = d.official_code AND d.geography_level_id = district_level_id
    LEFT JOIN catalog.block_districts bd ON b.id = bd.block_id AND d.id = bd.district_id
    WHERE bd.block_id IS NULL;
    
    -- AP Blocks logic: AP blocks have NO district_code in raw_data, but their logical_batch_key has DISTRICT!
    -- Wait, AP Blocks file DOES NOT HAVE DISTRICT in logical_batch_key!
    -- "ARUNACHAL PRADESH/All_Blockof_India_2026_08_27_00_21_21_218.zip!developmentblockofIndia2026:08:27:00:21:40:994.xls!!BLOCK!1"
    -- Wait, if the logical batch key is "All_Blockof_India", how do we map AP blocks to districts?
    -- The user explicitly said: "Preserve both District relationships for the 15 identified Block Codes. Do not select a District using row order or 'latest row wins'."
    
    RAISE NOTICE 'geography_units=%', (SELECT count(*) FROM catalog.geography_units);
    RAISE NOTICE 'development_blocks=%', (SELECT count(*) FROM catalog.development_blocks);
    RAISE NOTICE 'block_districts=%', (SELECT count(*) FROM catalog.block_districts);

END;
$$;

ROLLBACK;
