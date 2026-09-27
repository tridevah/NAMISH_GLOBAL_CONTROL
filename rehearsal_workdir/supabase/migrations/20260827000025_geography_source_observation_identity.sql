-- 20260827000025_geography_source_observation_identity.sql

ALTER TABLE staging.geography_imports
ADD COLUMN release_id UUID REFERENCES data_imports.releases(id),
ADD COLUMN source_observation_key TEXT,
ADD COLUMN physical_source_sha256 TEXT,
ADD COLUMN internal_member_or_sheet TEXT,
ADD COLUMN logical_output_ordinal INTEGER,
ADD COLUMN emitted_record_ordinal INTEGER,
ADD COLUMN raw_payload_sha256 TEXT,
ADD COLUMN canonical_identity_key TEXT,
ADD COLUMN observation_classification TEXT,
ADD COLUMN importer_replay_count BIGINT DEFAULT 0;

-- Unique identity
CREATE UNIQUE INDEX geography_imports_observation_identity_idx 
ON staging.geography_imports (release_id, batch_id, source_observation_key) 
WHERE source_observation_key IS NOT NULL;

CREATE OR REPLACE FUNCTION staging.trg_geography_imports_r10_check()
RETURNS TRIGGER AS $$
DECLARE
    v_release_name TEXT;
BEGIN
    SELECT release_name INTO v_release_name FROM data_imports.releases WHERE id = NEW.release_id;
    IF v_release_name = 'LGD_20260826_CORE_R10' THEN
        IF NEW.source_observation_key IS NULL THEN RAISE EXCEPTION 'source_observation_key cannot be NULL for R10'; END IF;
        IF NEW.physical_source_sha256 IS NULL THEN RAISE EXCEPTION 'physical_source_sha256 cannot be NULL for R10'; END IF;
        IF NEW.internal_member_or_sheet IS NULL THEN RAISE EXCEPTION 'internal_member_or_sheet cannot be NULL for R10'; END IF;
        IF NEW.physical_row_number IS NULL THEN RAISE EXCEPTION 'physical_row_number cannot be NULL for R10'; END IF;
        IF NEW.logical_output_ordinal IS NULL THEN RAISE EXCEPTION 'logical_output_ordinal cannot be NULL for R10'; END IF;
        IF NEW.emitted_record_ordinal IS NULL THEN RAISE EXCEPTION 'emitted_record_ordinal cannot be NULL for R10'; END IF;
        IF NEW.raw_payload_sha256 IS NULL THEN RAISE EXCEPTION 'raw_payload_sha256 cannot be NULL for R10'; END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_geography_imports_r10_check_trigger
BEFORE INSERT OR UPDATE ON staging.geography_imports
FOR EACH ROW EXECUTE FUNCTION staging.trg_geography_imports_r10_check();
