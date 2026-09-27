BEGIN;

-- 1. Add column
ALTER TABLE staging.geography_imports 
ADD COLUMN IF NOT EXISTS observation_identity_version text;

-- 2. Update trigger function
CREATE OR REPLACE FUNCTION staging.guard_release_lifecycle()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog
AS '
DECLARE
    v_release_status text;
    v_batch_status text;
    v_batch_release_id uuid;
BEGIN
    IF TG_OP = ''UPDATE'' OR TG_OP = ''DELETE'' THEN
        IF OLD.observation_identity_version = ''OBS_V3'' THEN
            RAISE EXCEPTION ''OBS_V3_IMMUTABILITY: UPDATE and DELETE are permanently rejected for raw source observations.'';
        END IF;
    END IF;
    
    IF TG_OP = ''INSERT'' THEN
        IF NEW.observation_identity_version = ''OBS_V3'' THEN
            IF NEW.source_observation_key IS NULL OR
               NEW.raw_payload_sha256 IS NULL OR
               NEW.physical_source_sha256 IS NULL OR
               NEW.internal_member_or_sheet IS NULL OR
               NEW.physical_row_number IS NULL OR
               NEW.logical_output_ordinal IS NULL OR
               NEW.emitted_record_ordinal IS NULL THEN
                RAISE EXCEPTION ''Missing OBS_V3 required field.'';
            END IF;
        END IF;

        SELECT r.status, b.status, b.release_id 
        INTO v_release_status, v_batch_status, v_batch_release_id
        FROM data_imports.releases r
        JOIN data_imports.batches b ON b.release_id = r.id
        WHERE b.id = NEW.batch_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION ''Nonmatching release/batch or batch does not exist.'';
        END IF;

        IF v_batch_release_id != NEW.release_id THEN
            RAISE EXCEPTION ''Nonmatching release/batch. batch_id does not belong to NEW.release_id.'';
        END IF;

        IF v_release_status IN (''INVALIDATED'', ''COMPLETED'', ''FINALIZED'') THEN
            RAISE EXCEPTION ''INVALIDATED, COMPLETED or FINALIZED release must reject inserts.'';
        END IF;

        IF v_batch_status != ''EXTRACTING'' THEN
            RAISE EXCEPTION ''Batch must be EXTRACTING to accept inserts (Current: %)'', v_batch_status;
        END IF;
    END IF;

    IF TG_OP = ''DELETE'' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
';

COMMIT;
