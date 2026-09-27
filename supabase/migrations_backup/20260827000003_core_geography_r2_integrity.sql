-- Migration 000013: Core Geography R2 Integrity Controls

-- 1. Invalidate previous release based on the audit
ALTER TABLE data_imports.releases
ADD COLUMN IF NOT EXISTS invalidated_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS invalidated_reason TEXT;

UPDATE data_imports.releases
SET invalidated_at = NOW(),
    invalidated_reason = 'FAILED_INCOMPLETE_CANONICAL - Missing mappings and lower hierarchy entities. See D:\ANTIGRAVITY_WORKSPACE\FINAL_CORE_GEOGRAPHY_RAW_EVIDENCE.txt'
WHERE release_name = 'LGD_COMPLETE' AND invalidated_at IS NULL;

-- 2. Enhance Staging Table for chunking, tracking, and classification
ALTER TABLE staging.geography_imports
ADD COLUMN IF NOT EXISTS source_filename TEXT,
ADD COLUMN IF NOT EXISTS sheet_name TEXT,
ADD COLUMN IF NOT EXISTS physical_row_number INT,
ADD COLUMN IF NOT EXISTS chunk_hash TEXT,
ADD COLUMN IF NOT EXISTS classification TEXT DEFAULT 'PENDING';

-- Create an index to quickly find unresolved parents or exact duplicates in staging
CREATE INDEX IF NOT EXISTS geo_imports_batch_entity_idx ON staging.geography_imports(batch_id, entity_type);
CREATE INDEX IF NOT EXISTS geo_imports_code_idx ON staging.geography_imports(entity_code);

-- 3. Database-controlled Finalization RPC
CREATE OR REPLACE FUNCTION data_imports.rpc_finalize_geography_release(
    p_release_id pg_catalog.uuid
) RETURNS pg_catalog.jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO pg_catalog
AS $$
DECLARE
    v_pending_batches INT;
    v_unresolved_parents INT;
    v_rejected INT;
    v_cross_state INT;
BEGIN
    -- Check for any non-completed batches (ignoring DEFERRED or OFFICIAL_EMPTY if marked as such, but we assume the launcher creates only expected batches)
    SELECT COUNT(*) INTO v_pending_batches 
    FROM data_imports.batches 
    WHERE release_id = p_release_id AND status NOT IN ('COMPLETED', 'OFFICIAL_EMPTY', 'DEFERRED');

    IF v_pending_batches > 0 THEN
        RAISE EXCEPTION 'Cannot finalize: % batches are not in COMPLETED/OFFICIAL_EMPTY/DEFERRED state.', v_pending_batches;
    END IF;

    -- Check for unresolved errors in staging for this release
    SELECT COUNT(*) INTO v_unresolved_parents
    FROM staging.geography_imports i
    JOIN data_imports.batches b ON i.batch_id = b.id
    WHERE b.release_id = p_release_id AND i.classification = 'UNRESOLVED_PARENT';

    IF v_unresolved_parents > 0 THEN
        RAISE EXCEPTION 'Cannot finalize: % unresolved parent conflicts exist.', v_unresolved_parents;
    END IF;

    -- Update release status
    UPDATE data_imports.releases
    SET status = 'COMPLETED', completed_at = NOW()
    WHERE id = p_release_id;

    RETURN pg_catalog.jsonb_build_object('status', 'SUCCESS', 'message', 'Release ' || p_release_id || ' finalized cleanly.');
END;
$$;
REVOKE ALL ON FUNCTION data_imports.rpc_finalize_geography_release(pg_catalog.uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION data_imports.rpc_finalize_geography_release(pg_catalog.uuid) TO service_role;
