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
    
    -- Find existing blocks
    WITH staged_blocks AS (
        SELECT DISTINCT (raw_data->>'block code')::int AS block_code,
               raw_data->>'block name' AS block_name,
               'ACTIVE' AS status 
        FROM staging.geography_imports
        WHERE release_id = v_release_id AND entity_type = 'BLOCK'
          AND raw_data->>'block code' IS NOT NULL
    ),
    existing_blocks AS (
        SELECT official_code::int, official_name, status
        FROM catalog.development_blocks
    ),
    inserts AS (
        SELECT s.* FROM staged_blocks s
        LEFT JOIN existing_blocks e ON s.block_code = e.official_code
        WHERE e.official_code IS NULL
    )
    SELECT count(*) INTO new_blocks_count FROM inserts;
    
    -- Attribute conflicts
    WITH staged_blocks AS (
        SELECT DISTINCT (raw_data->>'block code')::int AS block_code,
               raw_data->>'block name' AS block_name
        FROM staging.geography_imports
        WHERE release_id = v_release_id AND entity_type = 'BLOCK'
          AND raw_data->>'block code' IS NOT NULL
    ),
    existing_blocks AS (
        SELECT official_code::int, official_name
        FROM catalog.development_blocks
    ),
    conflicts AS (
        SELECT s.* FROM staged_blocks s
        JOIN existing_blocks e ON s.block_code = e.official_code
        WHERE UPPER(TRIM(s.block_name)) != UPPER(TRIM(e.official_name))
    )
    SELECT count(*) INTO invalid_attribute_conflicts FROM conflicts;
    
    -- Blank names
    SELECT count(*) INTO invalid_blank_names
    FROM staging.geography_imports
    WHERE release_id = v_release_id AND entity_type = 'BLOCK'
      AND (raw_data->>'block name' IS NULL OR trim(raw_data->>'block name') = '');
      
    -- Block relationships
    WITH relationships AS (
        SELECT DISTINCT (raw_data->>'block code')::int AS block_code,
               (raw_data->>'district code')::int AS district_code
        FROM staging.geography_imports
        WHERE release_id = v_release_id AND entity_type = 'BLOCK'
    ),
    existing_relationships AS (
        SELECT b.official_code::int AS block_code, d.official_code::int AS district_code
        FROM catalog.block_districts bd
        JOIN catalog.development_blocks b ON bd.block_id = b.id
        JOIN catalog.geography_units d ON bd.district_id = d.id
    ),
    new_rels AS (
        SELECT r.* FROM relationships r
        LEFT JOIN existing_relationships e ON r.block_code = e.block_code AND r.district_code = e.district_code
        WHERE e.block_code IS NULL
    )
    SELECT count(*) INTO new_block_districts_count FROM new_rels;
    
    -- Group counts
    WITH relationships AS (
        SELECT DISTINCT (raw_data->>'block code')::int AS block_code,
               (raw_data->>'district code')::int AS district_code
        FROM staging.geography_imports
        WHERE release_id = v_release_id AND entity_type = 'BLOCK'
    ),
    dist_counts AS (
        SELECT block_code, count(DISTINCT district_code) as c
        FROM relationships
        GROUP BY block_code
    )
    SELECT 
        sum(CASE WHEN c = 1 THEN 1 ELSE 0 END),
        sum(CASE WHEN c = 2 THEN 1 ELSE 0 END)
    INTO blocks_one_dist, blocks_two_dist
    FROM dist_counts;
    
    -- Perform mock inserts to verify constraints
    -- 1. Insert new blocks
    INSERT INTO catalog.development_blocks (id, official_code, official_name, status, district_id)
    SELECT gen_random_uuid(), s.block_code::text, s.block_name, 'ACTIVE', NULL
    FROM (
        SELECT DISTINCT (raw_data->>'block code')::int AS block_code,
               raw_data->>'block name' AS block_name
        FROM staging.geography_imports
        WHERE release_id = v_release_id AND entity_type = 'BLOCK'
          AND raw_data->>'block code' IS NOT NULL
    ) s
    LEFT JOIN catalog.development_blocks e ON s.block_code::text = e.official_code
    WHERE e.official_code IS NULL;
    
    -- 2. Insert new relationships
    INSERT INTO catalog.block_districts (block_id, district_id, source_release_id)
    SELECT b.id, d.id, v_release_id
    FROM (
        SELECT DISTINCT (raw_data->>'block code')::int AS block_code,
               (raw_data->>'district code')::int AS district_code
        FROM staging.geography_imports
        WHERE release_id = v_release_id AND entity_type = 'BLOCK'
    ) r
    JOIN catalog.development_blocks b ON r.block_code::text = b.official_code
    JOIN catalog.geography_units d ON r.district_code::text = d.official_code AND d.unit_type = 'DISTRICT'
    LEFT JOIN catalog.block_districts bd ON b.id = bd.block_id AND d.id = bd.district_id
    WHERE bd.block_id IS NULL;
    
    SELECT count(*) INTO post_db_blocks FROM catalog.development_blocks;
    SELECT count(*) INTO post_db_block_districts FROM catalog.block_districts;
    
    RAISE NOTICE 'REHEARSAL_RESULTS:';
    RAISE NOTICE 'new_blocks=%', new_blocks_count;
    RAISE NOTICE 'new_relationships=%', new_block_districts_count;
    RAISE NOTICE 'invalid_blank_names=%', invalid_blank_names;
    RAISE NOTICE 'invalid_attribute_conflicts=%', invalid_attribute_conflicts;
    RAISE NOTICE 'blocks_one_dist=%', blocks_one_dist;
    RAISE NOTICE 'blocks_two_dist=%', blocks_two_dist;
    RAISE NOTICE 'pre_db_blocks=%', pre_db_blocks;
    RAISE NOTICE 'post_db_blocks=%', post_db_blocks;
    RAISE NOTICE 'pre_db_block_districts=%', pre_db_block_districts;
    RAISE NOTICE 'post_db_block_districts=%', post_db_block_districts;

END;
$$;

ROLLBACK;
