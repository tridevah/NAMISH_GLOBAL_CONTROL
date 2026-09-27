-- =================================================================================
-- 20260830000034_multi_district_blocks.sql
-- =================================================================================

BEGIN;

-- 1. Create catalog.block_districts
CREATE TABLE catalog.block_districts (
    block_id pg_catalog.uuid NOT NULL REFERENCES catalog.development_blocks(id) ON DELETE CASCADE,
    district_id pg_catalog.uuid NOT NULL REFERENCES catalog.geography_units(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    source_release_id pg_catalog.uuid REFERENCES data_imports.releases(id),
    PRIMARY KEY (block_id, district_id)
);

CREATE INDEX block_districts_district_id_idx ON catalog.block_districts(district_id);

-- 2. Enable and FORCE RLS
ALTER TABLE catalog.block_districts ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog.block_districts FORCE ROW LEVEL SECURITY;

-- Grants & Policies
GRANT ALL ON catalog.block_districts TO service_role;
CREATE POLICY "service_role_all" ON catalog.block_districts FOR ALL TO service_role USING (true) WITH CHECK (true);

-- 3. Add database enforcement (Trigger)
CREATE OR REPLACE FUNCTION catalog.validate_block_district_relationship()
RETURNS TRIGGER AS $$
DECLARE
    v_district_level_key TEXT;
    v_district_country_id pg_catalog.uuid;
    v_district_state_id pg_catalog.uuid;
BEGIN
    -- Ensure district_id points to a DISTRICT
    SELECT l.level_key, g.country_id, g.parent_geography_unit_id 
    INTO v_district_level_key, v_district_country_id, v_district_state_id
    FROM catalog.geography_units g
    JOIN catalog.geography_levels l ON g.geography_level_id = l.id
    WHERE g.id = NEW.district_id;
    
    IF v_district_level_key != 'DISTRICT' THEN
        RAISE EXCEPTION 'Block can only be linked to a geography_unit of level DISTRICT (Got %)', COALESCE(v_district_level_key, 'NULL');
    END IF;
    
    -- Ensure all districts for this block belong to the same State and Country
    IF EXISTS (
        SELECT 1 FROM catalog.block_districts bd
        JOIN catalog.geography_units dist ON bd.district_id = dist.id
        WHERE bd.block_id = NEW.block_id 
        AND bd.district_id != NEW.district_id
        AND (dist.country_id != v_district_country_id OR dist.parent_geography_unit_id != v_district_state_id)
    ) THEN
        RAISE EXCEPTION 'Block cannot span across multiple States or Countries';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validate_block_district
BEFORE INSERT OR UPDATE ON catalog.block_districts
FOR EACH ROW EXECUTE FUNCTION catalog.validate_block_district_relationship();

-- 4. Preserve development_blocks.district_id temporarily
ALTER TABLE catalog.development_blocks ALTER COLUMN district_id DROP NOT NULL;
COMMENT ON COLUMN catalog.development_blocks.district_id IS 'DEPRECATED: Blocks can now span multiple districts. Use catalog.block_districts.';

-- Migrate any existing legacy references that are actually valid DISTRICTs
INSERT INTO catalog.block_districts (block_id, district_id)
SELECT b.id, b.district_id 
FROM catalog.development_blocks b
JOIN catalog.geography_units g ON b.district_id = g.id
JOIN catalog.geography_levels l ON g.geography_level_id = l.id
WHERE b.district_id IS NOT NULL AND l.level_key = 'DISTRICT'
ON CONFLICT DO NOTHING;

-- 5. Update rpc_get_development_blocks to return an array of district_ids
DROP FUNCTION IF EXISTS public.rpc_get_development_blocks();

CREATE OR REPLACE FUNCTION public.rpc_get_development_blocks()
RETURNS TABLE (
    id pg_catalog.uuid,
    district_ids pg_catalog.uuid[],
    official_code TEXT,
    official_name TEXT,
    status TEXT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    created_by pg_catalog.uuid,
    updated_by pg_catalog.uuid
) AS $$
BEGIN
    RETURN QUERY 
    SELECT 
        b.id,
        ARRAY(SELECT bd.district_id FROM catalog.block_districts bd WHERE bd.block_id = b.id) as district_ids,
        b.official_code,
        b.official_name,
        b.status,
        b.created_at,
        b.updated_at,
        b.created_by,
        b.updated_by
    FROM catalog.development_blocks b
    ORDER BY b.official_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.rpc_get_development_blocks() TO service_role;

COMMIT;
