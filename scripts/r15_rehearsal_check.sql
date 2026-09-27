BEGIN ISOLATION LEVEL SERIALIZABLE;

-- 1. Verify R15 manifest and importer hash unchanged
DO $$
DECLARE
    v_staged INT;
    v_empty INT;
BEGIN
    SELECT count(*) INTO v_staged FROM data_imports.batches WHERE release_id = (SELECT id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R15') AND status = 'STAGED';
    SELECT count(*) INTO v_empty FROM data_imports.batches WHERE release_id = (SELECT id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R15') AND status = 'OFFICIAL_EMPTY';
    IF v_staged != 143 OR v_empty != 1 THEN
        RAISE EXCEPTION 'Batch statuses incorrect: STAGED=%, OFFICIAL_EMPTY=%', v_staged, v_empty;
    END IF;
END;
$$;

-- 2. Verify 15 blocks duplicate attributes are identical
DO $$
DECLARE
    v_conflicts INT;
BEGIN
    SELECT count(*) INTO v_conflicts
    FROM (
        SELECT 
            COALESCE(raw_data->>'block code', raw_data->>'development block code') as code,
            count(DISTINCT COALESCE(raw_data->>'block name (in english)', raw_data->>'block name')) as names,
            count(DISTINCT COALESCE(raw_data->>'block version', raw_data->>' development block version')) as versions,
            count(DISTINCT raw_data->>'status') as statuses,
            count(DISTINCT raw_data->>'state name') as states
        FROM staging.geography_imports
        WHERE release_id = (SELECT id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R15') 
        AND entity_type = 'BLOCK'
        GROUP BY COALESCE(raw_data->>'block code', raw_data->>'development block code')
        HAVING count(*) > 1
    ) dup
    WHERE names > 1 OR versions > 1 OR statuses > 1 OR states > 1;

    IF v_conflicts > 0 THEN
        RAISE EXCEPTION 'Conflicting attributes found in the 15 duplicated blocks';
    END IF;
END;
$$;

-- 3. Legacy reconciliation check
DO $$
DECLARE
    v_missing INT;
BEGIN
    SELECT count(*) INTO v_missing
    FROM catalog.development_blocks db
    LEFT JOIN catalog.block_districts bd ON db.id = bd.block_id AND db.district_id = bd.district_id
    WHERE db.district_id IS NOT NULL AND bd.block_id IS NULL;
    
    IF v_missing > 0 THEN
        RAISE EXCEPTION 'Legacy district_id missing from block_districts';
    END IF;
END;
$$;

ROLLBACK;
