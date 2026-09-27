BEGIN ISOLATION LEVEL SERIALIZABLE;

DO $$
DECLARE
    v_release_id uuid;
BEGIN
    SELECT id INTO v_release_id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R16';
    
    -- Insert new blocks
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
    
    -- Insert new relationships
    INSERT INTO catalog.block_districts (block_id, district_id, source_release_id)
    SELECT b.id, d.id, v_release_id
    FROM (
        SELECT DISTINCT (COALESCE(raw_data->>'block code', raw_data->>'development block code'))::int AS block_code,
               (COALESCE(raw_data->>'district code', raw_data->>'district code'))::int AS district_code
        FROM staging.geography_imports
        WHERE release_id = v_release_id AND entity_type = 'BLOCK'
          AND raw_data->>'district code' IS NOT NULL
    ) r
    JOIN catalog.development_blocks b ON r.block_code::text = b.official_code
    JOIN catalog.geography_units d ON r.district_code::text = d.official_code
    LEFT JOIN catalog.block_districts bd ON b.id = bd.block_id AND d.id = bd.district_id
    WHERE bd.block_id IS NULL;
    
    RAISE NOTICE 'block_districts=%', (SELECT count(*) FROM catalog.block_districts);
END;
$$;

ROLLBACK;
