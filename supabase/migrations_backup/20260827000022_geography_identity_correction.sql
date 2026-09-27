-- 000022_geography_identity_correction.sql

-- Drop the unique constraint on name/parent, making it a regular search index
DROP INDEX IF EXISTS catalog.geo_units_normalized_name_idx;

CREATE INDEX IF NOT EXISTS geo_units_normalized_name_idx 
ON catalog.geography_units (country_id, geography_level_id, COALESCE(parent_geography_unit_id, '00000000-0000-0000-0000-000000000000'::uuid), upper(official_name));
