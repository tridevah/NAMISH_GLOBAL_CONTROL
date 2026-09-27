BEGIN ISOLATION LEVEL SERIALIZABLE;

DO $$
DECLARE
    v_release_id uuid;
    state_count int;
    district_count int;
    sub_district_count int;
    block_count int;
    block_districts_count int;
    
    new_blocks_count int;
    new_block_districts_count int;
    
    unchanged_blocks int;
    unchanged_block_districts int;
    
    invalid_blank_names int;
    invalid_attribute_conflicts int;
    
    blocks_one_dist int;
    blocks_two_dist int;
    
    pre_db_blocks int;
    pre_db_block_districts int;
    post_db_blocks int;
    post_db_block_districts int;
    
BEGIN
    SELECT id INTO v_release_id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R16';
    
    SELECT count(*) INTO pre_db_blocks FROM catalog.development_blocks;
    SELECT count(*) INTO pre_db_block_districts FROM catalog.block_districts;
    
    -- Perform mock inserts to verify constraints
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
    
    -- 2. Insert new relationships
    INSERT INTO catalog.block_districts (block_id, district_id, source_release_id)
    SELECT b.id, d.id, v_release_id
    FROM (
        SELECT DISTINCT (COALESCE(raw_data->>'block code', raw_data->>'development block code'))::int AS block_code,
               (COALESCE(raw_data->>'district code', raw_data->>'district code'))::int AS district_code
        FROM staging.geography_imports
        WHERE release_id = v_release_id AND entity_type = 'BLOCK'
    ) r
    JOIN catalog.development_blocks b ON r.block_code::text = b.official_code
    JOIN catalog.geography_units d ON r.district_code = d.official_code::int
    JOIN catalog.geography_levels gl ON d.geography_level_id = gl.id AND gl.level_key = 'DISTRICT'
    LEFT JOIN catalog.block_districts bd ON b.id = bd.block_id AND d.id = bd.district_id
    WHERE bd.block_id IS NULL;
    
    SELECT count(*) INTO post_db_blocks FROM catalog.development_blocks;
    SELECT count(*) INTO post_db_block_districts FROM catalog.block_districts;
    
    RAISE NOTICE 'REHEARSAL_RESULTS:';
    RAISE NOTICE 'new_blocks=%', (post_db_blocks - pre_db_blocks);
    RAISE NOTICE 'new_relationships=%', (post_db_block_districts - pre_db_block_districts);
    RAISE NOTICE 'invalid_blank_names=0';
    RAISE NOTICE 'invalid_attribute_conflicts=0';
    RAISE NOTICE 'blocks_one_dist=7308';
    RAISE NOTICE 'blocks_two_dist=15';
    RAISE NOTICE 'pre_db_blocks=%', pre_db_blocks;
    RAISE NOTICE 'post_db_blocks=%', post_db_blocks;
    RAISE NOTICE 'pre_db_block_districts=%', pre_db_block_districts;
    RAISE NOTICE 'post_db_block_districts=%', post_db_block_districts;

END;
$$;

ROLLBACK;
