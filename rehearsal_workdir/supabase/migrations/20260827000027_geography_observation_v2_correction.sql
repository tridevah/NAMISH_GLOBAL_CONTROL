-- 20260827000027_geography_observation_v2_correction.sql

-- 1. Rename replay count columns to occurrence_count
ALTER TABLE data_imports.row_errors RENAME COLUMN importer_replay_count TO occurrence_count;
ALTER TABLE catalog.post_office_identity_reviews RENAME COLUMN importer_replay_count TO occurrence_count;

-- 2. Trigger for Payload Collision in Postgres
CREATE OR REPLACE FUNCTION staging.trg_check_payload_collision()
RETURNS TRIGGER AS $$
DECLARE
    v_existing_hash TEXT;
BEGIN
    IF NEW.source_observation_key IS NOT NULL THEN
        -- Only check on INSERT
        IF TG_OP = 'INSERT' THEN
            SELECT raw_payload_sha256 INTO v_existing_hash 
            FROM staging.geography_imports 
            WHERE release_id = NEW.release_id 
              AND batch_id = NEW.batch_id 
              AND source_observation_key = NEW.source_observation_key;
              
            IF FOUND AND v_existing_hash != NEW.raw_payload_sha256 THEN
                RAISE EXCEPTION 'OBSERVATION_KEY_COLLISION';
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_geography_imports_payload_check
BEFORE INSERT ON staging.geography_imports
FOR EACH ROW EXECUTE FUNCTION staging.trg_check_payload_collision();

-- 3. Extend NOT NULL constraints trigger for R11
CREATE OR REPLACE FUNCTION staging.trg_geography_imports_r10_check()
RETURNS TRIGGER AS $$
DECLARE
    v_release_name TEXT;
BEGIN
    SELECT release_name INTO v_release_name FROM data_imports.releases WHERE id = NEW.release_id;
    IF v_release_name LIKE 'LGD_20260826_CORE_R%' THEN
        IF NEW.source_observation_key IS NULL THEN RAISE EXCEPTION 'source_observation_key cannot be NULL'; END IF;
        IF NEW.physical_source_sha256 IS NULL THEN RAISE EXCEPTION 'physical_source_sha256 cannot be NULL'; END IF;
        IF NEW.internal_member_or_sheet IS NULL THEN RAISE EXCEPTION 'internal_member_or_sheet cannot be NULL'; END IF;
        IF NEW.physical_row_number IS NULL THEN RAISE EXCEPTION 'physical_row_number cannot be NULL'; END IF;
        IF NEW.logical_output_ordinal IS NULL THEN RAISE EXCEPTION 'logical_output_ordinal cannot be NULL'; END IF;
        IF NEW.emitted_record_ordinal IS NULL THEN RAISE EXCEPTION 'emitted_record_ordinal cannot be NULL'; END IF;
        IF NEW.raw_payload_sha256 IS NULL THEN RAISE EXCEPTION 'raw_payload_sha256 cannot be NULL'; END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
