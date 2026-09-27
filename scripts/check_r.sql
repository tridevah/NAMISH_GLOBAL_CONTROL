BEGIN;
    SELECT count(*)
    FROM (
        SELECT DISTINCT (COALESCE(raw_data->>'block code', raw_data->>'development block code'))::int AS block_code,
               (COALESCE(raw_data->>'district code', raw_data->>'district code'))::int AS district_code
        FROM staging.geography_imports
        WHERE release_id = '5fac63d7-0101-43c5-8867-bd75ff609861' AND entity_type = 'BLOCK'
    ) r;
ROLLBACK;
