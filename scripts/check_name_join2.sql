BEGIN;
    SELECT count(*)
    FROM (
        SELECT DISTINCT (COALESCE(raw_data->>'block code', raw_data->>'development block code'))::int AS block_code,
               raw_data->>'district name' AS district_name
        FROM staging.geography_imports
        WHERE release_id = '5fac63d7-0101-43c5-8867-bd75ff609861' AND entity_type = 'BLOCK'
    ) r
    JOIN catalog.geography_units d ON upper(r.district_name) = upper(d.official_name) 
         AND d.geography_level_id = (SELECT id FROM catalog.geography_levels WHERE level_key = 'DISTRICT');
ROLLBACK;
