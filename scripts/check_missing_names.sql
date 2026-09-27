BEGIN;
    SELECT raw_data->>'district name' as dist_name, count(*) 
    FROM staging.geography_imports r
    WHERE release_id = '5fac63d7-0101-43c5-8867-bd75ff609861' AND entity_type = 'BLOCK'
    AND NOT EXISTS (
        SELECT 1 FROM catalog.geography_units d 
        WHERE upper(d.official_name) = upper(r.raw_data->>'district name')
        AND d.geography_level_id = (SELECT id FROM catalog.geography_levels WHERE level_key = 'DISTRICT')
    )
    GROUP BY raw_data->>'district name'
    LIMIT 10;
ROLLBACK;
