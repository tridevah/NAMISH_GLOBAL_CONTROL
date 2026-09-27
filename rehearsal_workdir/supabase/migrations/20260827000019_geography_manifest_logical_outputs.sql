-- 000019_geography_manifest_logical_outputs.sql

-- Drop the old constraint and add a new table for logical outputs
CREATE TABLE IF NOT EXISTS data_imports.release_manifest_logical_outputs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    release_id UUID NOT NULL REFERENCES data_imports.releases(id) ON DELETE CASCADE,
    manifest_entry_id UUID NOT NULL REFERENCES data_imports.release_manifest_entries(id) ON DELETE CASCADE,
    logical_entity TEXT NOT NULL,
    status TEXT DEFAULT 'PENDING',
    UNIQUE(release_id, manifest_entry_id, logical_entity)
);

-- Replace finalizer to check logical outputs
CREATE OR REPLACE FUNCTION data_imports.rpc_finalize_geography_release(p_release_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_pending_batches INT;
    v_unresolved_parents INT;
    v_missing_entries INT;
BEGIN
    -- Check that EVERY logical output expected has a COMPLETED or NOT_APPLICABLE batch
    SELECT COUNT(*) INTO v_missing_entries
    FROM data_imports.release_manifest_logical_outputs lo
    JOIN data_imports.release_manifest_entries m ON m.id = lo.manifest_entry_id
    LEFT JOIN data_imports.batches b ON b.release_id = p_release_id AND b.entity_type = lo.logical_entity
    WHERE lo.release_id = p_release_id 
      AND m.role = 'IMPORT_AUTHORITY' 
      AND (b.id IS NULL OR b.status NOT IN ('COMPLETED', 'NOT_APPLICABLE', 'OFFICIAL_EMPTY'));

    IF v_missing_entries > 0 THEN
        RAISE EXCEPTION 'Cannot finalize: % expected logical batches are missing or not completed.', v_missing_entries;
    END IF;

    -- Check for unresolved errors in staging for this release
    SELECT COUNT(*) INTO v_unresolved_parents
    FROM staging.geography_imports i
    JOIN data_imports.batches b ON i.batch_id = b.id
    WHERE b.release_id = p_release_id AND i.classification = 'UNRESOLVED_PARENT';

    IF v_unresolved_parents > 0 THEN
        RAISE EXCEPTION 'Cannot finalize: % unresolved parent conflicts exist.', v_unresolved_parents;
    END IF;

    -- Check pending explicitly
    SELECT COUNT(*) INTO v_pending_batches 
    FROM data_imports.batches 
    WHERE release_id = p_release_id AND status NOT IN ('COMPLETED', 'OFFICIAL_EMPTY', 'DEFERRED', 'NOT_APPLICABLE');

    IF v_pending_batches > 0 THEN
        RAISE EXCEPTION 'Cannot finalize: % batches are not in COMPLETED state.', v_pending_batches;
    END IF;

    -- Update release status
    UPDATE data_imports.releases
    SET status = 'COMPLETED', completed_at = NOW()
    WHERE id = p_release_id;

    RETURN pg_catalog.jsonb_build_object('status', 'SUCCESS', 'message', 'Release ' || p_release_id || ' finalized cleanly.');
END;
$$;
