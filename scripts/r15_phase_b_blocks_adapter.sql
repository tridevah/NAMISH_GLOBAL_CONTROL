-- =================================================================================
-- r15_phase_b_blocks_adapter.sql
-- (DRAFT - NOT TO BE EXECUTED YET)
-- =================================================================================

-- 1. Insert 7,323 unique Blocks (Using distinct official code)
INSERT INTO catalog.development_blocks (id, official_code, official_name, status, created_at, updated_at)
SELECT 
    gen_random_uuid(), -- or deterministically generated based on official code
    code,
    name,
    'ACTIVE',
    NOW(),
    NOW()
FROM (
    SELECT DISTINCT ON (COALESCE(raw_data->>'block code', raw_data->>'development block code'))
        COALESCE(raw_data->>'block code', raw_data->>'development block code') as code,
        COALESCE(raw_data->>'block name', raw_data->>'development block name (in english)') as name
    FROM staging.geography_imports
    WHERE release_id = (SELECT id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R15')
    AND entity_type = 'BLOCK'
    ORDER BY COALESCE(raw_data->>'block code', raw_data->>'development block code'), physical_row_number ASC
) as unique_blocks
ON CONFLICT (official_code) DO NOTHING;

-- 2. Insert 7,338 distinct Block-District relationships
INSERT INTO catalog.block_districts (block_id, district_id)
SELECT DISTINCT 
    b.id,
    g.id
FROM staging.geography_imports s
-- Map to canonical block by official_code
JOIN catalog.development_blocks b 
    ON b.official_code = COALESCE(s.raw_data->>'block code', s.raw_data->>'development block code')
-- Map to canonical district by official district code
JOIN catalog.geography_units g 
    ON g.official_code = COALESCE(s.raw_data->>'district code', s.raw_data->>'district code')
    AND g.geography_level_id = (SELECT id FROM catalog.geography_levels WHERE level_key = 'DISTRICT')
WHERE s.release_id = (SELECT id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R15')
AND s.entity_type = 'BLOCK'
ON CONFLICT DO NOTHING;
