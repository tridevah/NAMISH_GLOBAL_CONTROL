-- Migration 20260904000006: Restore Uniqueness and Update Status
BEGIN;

-- 1. Drop any legacy code-only unique constraint (from manual remote DDL or prior local state)
ALTER TABLE catalog.hsn_sac 
    DROP CONSTRAINT IF EXISTS hsn_sac_code_key;

-- 2. Restore correct uniqueness combining country, type, and code
ALTER TABLE catalog.hsn_sac 
    ADD CONSTRAINT hsn_sac_country_type_code_key UNIQUE (country_id, code_type, code);

-- 3. Modify status constraint to accept the new status
ALTER TABLE catalog.hsn_sac 
    DROP CONSTRAINT IF EXISTS hsn_sac_status_check;

ALTER TABLE catalog.hsn_sac 
    ADD CONSTRAINT hsn_sac_status_check 
    CHECK (status IN ('ACTIVE', 'INACTIVE', 'TOP_LEVEL_CLASSIFICATION_ONLY'));

-- 4. Update the dataset status to explicitly indicate it is not the complete code master
UPDATE catalog.hsn_sac 
   SET status = 'TOP_LEVEL_CLASSIFICATION_ONLY';

COMMIT;
