BEGIN;
ALTER TABLE catalog.geography_units DISABLE TRIGGER USER;
-- Fix States
INSERT INTO catalog.geography_units (id, country_id, geography_level_id, official_code, official_name, display_name, status)
SELECT gen_random_uuid(), (SELECT id FROM catalog.countries WHERE iso3 = 'IND'), 
       (SELECT id FROM catalog.geography_levels WHERE level_key = 'STATE_UT'),
       COALESCE(substring(raw_data->>'TITLE' from 'State Code:(\d+)'), 'UNKNOWN_' || md5(random()::text)),
       COALESCE(substring(raw_data->>'TITLE' from 'All Districts of (.*?)\('), 'Unknown'),
       COALESCE(substring(raw_data->>'TITLE' from 'All Districts of (.*?)\('), 'Unknown'),
       'ACTIVE'
FROM staging.geography_imports 
WHERE release_id = '5fac63d7-0101-43c5-8867-bd75ff609861' AND entity_type = 'STATE'
ON CONFLICT DO NOTHING;

-- Fix Districts
INSERT INTO catalog.geography_units (id, country_id, geography_level_id, official_code, official_name, display_name, status)
SELECT gen_random_uuid(), (SELECT id FROM catalog.countries WHERE iso3 = 'IND'), 
       (SELECT id FROM catalog.geography_levels WHERE level_key = 'DISTRICT'),
       COALESCE(raw_data->>'district code', 'UNKNOWN_' || md5(random()::text)),
       COALESCE(raw_data->>'district name (in english)', raw_data->>'district name', 'Unknown'),
       COALESCE(raw_data->>'district name (in english)', raw_data->>'district name', 'Unknown'),
       'ACTIVE'
FROM staging.geography_imports 
WHERE release_id = '5fac63d7-0101-43c5-8867-bd75ff609861' AND entity_type = 'DISTRICT'
ON CONFLICT DO NOTHING;

-- Fix Sub-Districts
INSERT INTO catalog.geography_units (id, country_id, geography_level_id, official_code, official_name, display_name, status)
SELECT gen_random_uuid(), (SELECT id FROM catalog.countries WHERE iso3 = 'IND'), 
       (SELECT id FROM catalog.geography_levels WHERE level_key = 'SUB_DISTRICT'),
       COALESCE(raw_data->>'sub-district code', raw_data->>'subdistrict code', 'UNKNOWN_' || md5(random()::text)),
       COALESCE(raw_data->>'sub-district name (in english)', raw_data->>'subdistrict name (in english)', 'Unknown'),
       COALESCE(raw_data->>'sub-district name (in english)', raw_data->>'subdistrict name (in english)', 'Unknown'),
       'ACTIVE'
FROM staging.geography_imports 
WHERE release_id = '5fac63d7-0101-43c5-8867-bd75ff609861' AND entity_type = 'SUB_DISTRICT'
ON CONFLICT DO NOTHING;
ALTER TABLE catalog.geography_units ENABLE TRIGGER USER;
COMMIT;
