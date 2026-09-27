import json

with open('seed/unece_parsed.json', 'r', encoding='utf-8') as f:
    seed = json.load(f)

# Need to dump units, uqc_mappings, and conversions as JSON literals
units_json = json.dumps(seed['units']).replace("'", "''")
uqc_json = json.dumps(seed['india_uqc_mappings']).replace("'", "''")
conv_json = json.dumps(seed['unit_conversions']).replace("'", "''")

with open('supabase/migrations/20260918000001_unit_master_schema.sql', 'r', encoding='utf-8') as f:
    migration_sql = f.read()

# Replace BEGIN; and COMMIT;
migration_sql = migration_sql.replace("BEGIN;", "").replace("COMMIT;", "")

rehearsal_sql = f"""BEGIN;

-- Include complete forward migration
{migration_sql}

-- Run Rehearsal
DO $rehearsal
DECLARE
    v_units JSONB := '{units_json}'::jsonb;
    v_uqc_mappings JSONB := '{uqc_json}'::jsonb;
    v_conversions JSONB := '{conv_json}'::jsonb;
    v_res JSONB;
BEGIN
    RAISE NOTICE 'Starting Rehearsal Import...';
    v_res := public.import_unit_master(v_units, v_uqc_mappings, v_conversions);
    
    RAISE NOTICE 'Import 1: %', v_res;
    
    IF (v_res->>'units_inserted')::INT != {len(seed['units'])} THEN
        RAISE EXCEPTION 'Failed initial import units: % inserted', (v_res->>'units_inserted');
    END IF;

    -- Run Identical Re-import
    v_res := public.import_unit_master(v_units, v_uqc_mappings, v_conversions);
    RAISE NOTICE 'Import 2 (Re-import): %', v_res;
    
    IF (v_res->>'units_unchanged')::INT != {len(seed['units'])} THEN
        RAISE EXCEPTION 'Failed identical re-import: expected unchanged to be max';
    END IF;
    IF (v_res->>'units_inserted')::INT != 0 THEN
        RAISE EXCEPTION 'Failed identical re-import: inserted should be 0';
    END IF;
    
    -- Intentionally mutate to trigger rejection
    BEGIN
        v_res := public.import_unit_master(
            '[{{"canonical_code": "UNECE_REC20_MTR", "standard_code": "MTR", "name": "Meters Mutated", "symbol": "m", "category": "GENERAL", "status": "ACTIVE", "source_status": "A", "source": "UNECE_REC20", "source_version": "1"}}]'::jsonb,
            '[]'::jsonb, '[]'::jsonb
        );
        RAISE EXCEPTION 'Failed to reject unreviewed overwrite!';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Successfully rejected conflicting definition: %', SQLERRM;
    END;

    RAISE NOTICE 'Rehearsal Assertions Passed Successfully.';
END $rehearsal;

ROLLBACK;
"""

with open('unit_master_rehearsal.sql', 'w', encoding='utf-8') as f:
    f.write(rehearsal_sql)

print("Created unit_master_rehearsal.sql")
