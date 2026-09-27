BEGIN ISOLATION LEVEL SERIALIZABLE;
SELECT pg_advisory_xact_lock(hashtext('LGD_CORE_PROMOTION'));

DO $$
DECLARE
    v_release_id uuid := '5fac63d7-0101-43c5-8867-bd75ff609861';
    v_verify_release_id uuid;
    state_level_id uuid;
    district_level_id uuid;
    subdistrict_level_id uuid;
    india_id uuid;
    
    c_states int;
    c_districts int;
    c_subdistricts int;
    c_blocks int;
    c_rels int;
    
    i_states int;
    i_districts int;
    i_subdistricts int;
    i_blocks int;
    i_rels int;
BEGIN
    SELECT id INTO v_verify_release_id FROM data_imports.releases WHERE id = v_release_id;
    IF v_verify_release_id IS NULL THEN
        RAISE EXCEPTION 'Release % not found', v_release_id;
    END IF;

    SELECT id INTO india_id FROM catalog.countries WHERE iso3 = 'IND';
    SELECT id INTO state_level_id FROM catalog.geography_levels WHERE level_key = 'STATE_UT';
    SELECT id INTO district_level_id FROM catalog.geography_levels WHERE level_key = 'DISTRICT';
    SELECT id INTO subdistrict_level_id FROM catalog.geography_levels WHERE level_key = 'SUB_DISTRICT';

    -- 1. States
    WITH s AS (
        INSERT INTO catalog.geography_units (country_id, geography_level_id, official_code, official_name, display_name, status)
        SELECT india_id, state_level_id, 
               COALESCE(substring(raw_data->>'TITLE' from 'State Code:(\d+)'), 'UNKNOWN_STATE'), 
               COALESCE(substring(raw_data->>'TITLE' from 'All Districts of (.*?)\('), 'Unknown'), 
               COALESCE(substring(raw_data->>'TITLE' from 'All Districts of (.*?)\('), 'Unknown'), 
               'ACTIVE'
        FROM staging.geography_imports
        WHERE release_id = v_release_id AND entity_type = 'STATE'
        ON CONFLICT (country_id, geography_level_id, official_code) DO NOTHING
        RETURNING 1
    )
    SELECT count(*) INTO i_states FROM s;

    -- 2. Districts
    WITH s AS (
        INSERT INTO catalog.geography_units (country_id, geography_level_id, official_code, official_name, display_name, status)
        SELECT india_id, district_level_id, 
               (raw_data->>'district code')::text, 
               COALESCE(raw_data->>'district name (in english)', raw_data->>'district name', 'Unknown'), 
               COALESCE(raw_data->>'district name (in english)', raw_data->>'district name', 'Unknown'), 
               'ACTIVE'
        FROM staging.geography_imports
        WHERE release_id = v_release_id AND entity_type = 'DISTRICT'
        ON CONFLICT (country_id, geography_level_id, official_code) DO NOTHING
        RETURNING 1
    )
    SELECT count(*) INTO i_districts FROM s;

    -- 3. Sub-Districts
    WITH s AS (
        INSERT INTO catalog.geography_units (country_id, geography_level_id, official_code, official_name, display_name, status)
        SELECT india_id, subdistrict_level_id, 
               COALESCE(raw_data->>'sub-district code', raw_data->>'subdistrict code')::text, 
               COALESCE(raw_data->>'sub-district name (in english)', raw_data->>'subdistrict name (in english)', 'Unknown'), 
               COALESCE(raw_data->>'sub-district name (in english)', raw_data->>'subdistrict name (in english)', 'Unknown'), 
               'ACTIVE'
        FROM staging.geography_imports
        WHERE release_id = v_release_id AND entity_type = 'SUB_DISTRICT'
        ON CONFLICT (country_id, geography_level_id, official_code) DO NOTHING
        RETURNING 1
    )
    SELECT count(*) INTO i_subdistricts FROM s;

    -- 4. Blocks
    WITH staged_blocks AS (
        SELECT DISTINCT (COALESCE(raw_data->>'block code', raw_data->>'development block code'))::int AS block_code,
               COALESCE(raw_data->>'block name', raw_data->>'development block name (in english)') AS block_name
        FROM staging.geography_imports
        WHERE release_id = v_release_id AND entity_type = 'BLOCK'
          AND COALESCE(raw_data->>'block code', raw_data->>'development block code') IS NOT NULL
    ),
    new_blocks AS (
        SELECT s.block_code::text, s.block_name
        FROM staged_blocks s
        LEFT JOIN catalog.development_blocks e ON s.block_code::text = e.official_code
        WHERE e.official_code IS NULL
    ),
    s AS (
        INSERT INTO catalog.development_blocks (id, official_code, official_name, status, district_id)
        SELECT gen_random_uuid(), block_code, block_name, 'ACTIVE', NULL
        FROM new_blocks
        RETURNING 1
    )
    SELECT count(*) INTO i_blocks FROM s;
    
    -- 5. Block Relationships
    WITH staged_rels AS (
        SELECT DISTINCT (COALESCE(raw_data->>'block code', raw_data->>'development block code'))::int AS block_code,
               (COALESCE(raw_data->>'district code', raw_data->>'district code'))::int AS district_code
        FROM staging.geography_imports
        WHERE release_id = v_release_id AND entity_type = 'BLOCK'
          AND raw_data->>'district code' IS NOT NULL
    ),
    valid_rels AS (
        SELECT b.id AS block_id, d.id AS district_id
        FROM staged_rels r
        JOIN catalog.development_blocks b ON r.block_code::text = b.official_code
        JOIN catalog.geography_units d ON r.district_code = d.official_code::int 
             AND d.geography_level_id = district_level_id
    ),
    new_rels AS (
        SELECT v.block_id, v.district_id
        FROM valid_rels v
        LEFT JOIN catalog.block_districts bd ON v.block_id = bd.block_id AND v.district_id = bd.district_id
        WHERE bd.block_id IS NULL
    ),
    s AS (
        INSERT INTO catalog.block_districts (block_id, district_id, source_release_id)
        SELECT block_id, district_id, v_release_id
        FROM new_rels
        RETURNING 1
    )
    SELECT count(*) INTO i_rels FROM s;

    -- Assertions
    SELECT count(*) INTO c_states FROM catalog.geography_units WHERE geography_level_id = state_level_id;
    SELECT count(*) INTO c_districts FROM catalog.geography_units WHERE geography_level_id = district_level_id;
    SELECT count(*) INTO c_subdistricts FROM catalog.geography_units WHERE geography_level_id = subdistrict_level_id;
    SELECT count(*) INTO c_blocks FROM catalog.development_blocks;
    SELECT count(*) INTO c_rels FROM catalog.block_districts;

    RAISE NOTICE 'geography_units (STATE_UT): % (inserted %)', c_states, i_states;
    RAISE NOTICE 'geography_units (DISTRICT): % (inserted %)', c_districts, i_districts;
    RAISE NOTICE 'geography_units (SUB_DISTRICT): % (inserted %)', c_subdistricts, i_subdistricts;
    RAISE NOTICE 'development_blocks: % (inserted %)', c_blocks, i_blocks;
    RAISE NOTICE 'block_districts: % (inserted %)', c_rels, i_rels;
    
    IF c_states != 36 THEN RAISE EXCEPTION 'Assertion failed: expected 36 STATES, got %', c_states; END IF;
    IF c_districts != 784 THEN RAISE EXCEPTION 'Assertion failed: expected 784 DISTRICTS, got %', c_districts; END IF;
    IF c_subdistricts != 7092 THEN RAISE EXCEPTION 'Assertion failed: expected 7092 SUB_DISTRICTS, got %', c_subdistricts; END IF;
    IF c_blocks != 7323 THEN RAISE EXCEPTION 'Assertion failed: expected 7323 DEVELOPMENT_BLOCKS, got %', c_blocks; END IF;
    IF c_rels != 7338 THEN RAISE EXCEPTION 'Assertion failed: expected 7338 BLOCK_DISTRICTS, got %', c_rels; END IF;
END;
$$;

ROLLBACK;
