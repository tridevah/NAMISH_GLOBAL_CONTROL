BEGIN;
    SELECT r.district_code, r.block_code
    FROM (
        SELECT DISTINCT (COALESCE(raw_data->>'block code', raw_data->>'development block code'))::int AS block_code,
               (COALESCE(raw_data->>'district code', raw_data->>'district code'))::int AS district_code
        FROM staging.geography_imports
        WHERE release_id = '5fac63d7-0101-43c5-8867-bd75ff609861' AND entity_type = 'BLOCK'
    ) r
    JOIN catalog.development_blocks b ON r.block_code::text = b.official_code
    LEFT JOIN catalog.geography_units d ON r.district_code = d.official_code::int AND d.geography_level_id IN (SELECT id FROM catalog.geography_levels WHERE level_key = 'DISTRICT')
    WHERE d.id IS NULL
    LIMIT 10;
ROLLBACK;
