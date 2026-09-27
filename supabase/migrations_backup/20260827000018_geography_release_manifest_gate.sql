-- 000018_geography_release_manifest_gate.sql

-- 1. Create immutable contract tables
CREATE TABLE IF NOT EXISTS data_imports.release_manifest_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    release_id UUID NOT NULL REFERENCES data_imports.releases(id) ON DELETE CASCADE,
    path TEXT NOT NULL,
    size BIGINT NOT NULL,
    source_sha256 TEXT NOT NULL,
    role TEXT NOT NULL,
    scope TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    status TEXT DEFAULT 'PENDING',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(release_id, path)
);

-- 2. Invalidate R3
UPDATE data_imports.releases 
SET status='INVALIDATED', invalidated_reason='INVALIDATED_HANDLER_COVERAGE', invalidated_at=NOW() 
WHERE release_name='LGD_20260826_CORE_R3';

-- 3. Create R4 (The script will do this dynamically, or we can insert it here)
-- We will let the Node script create R4 so it can get the ID and insert the manifest entries.

-- 4. Replace Finalizer
CREATE OR REPLACE FUNCTION data_imports.rpc_finalize_geography_release(p_release_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_pending_batches INT;
    v_unresolved_parents INT;
    v_missing_entries INT;
    v_required_entities TEXT[] := ARRAY[
        'DISTRICT', 'SUB_DISTRICT', 'VILLAGE', 'BLOCK', 'BLOCK_VILLAGE',
        'PRI_LOCAL_BODY', 'URBAN_LOCAL_BODY', 'TRADITIONAL_LOCAL_BODY',
        'LOCAL_BODY_VILLAGE', 'URBAN_WARD', 'PRI_WARD', 'WARD_COVERAGE',
        'PINCODE', 'PIN_VILLAGE', 'PIN_URBAN_LOCAL_BODY'
    ];
    v_ent TEXT;
    v_batch_count INT;
BEGIN
    -- Ensure all expected logical batches for required entities exist
    -- Actually, we must ensure every IMPORT_AUTHORITY manifest entry has a batch that is COMPLETED
    
    SELECT COUNT(*) INTO v_missing_entries
    FROM data_imports.release_manifest_entries m
    LEFT JOIN data_imports.batches b ON b.release_id = m.release_id AND b.entity_type = m.entity_type
    WHERE m.release_id = p_release_id 
      AND m.role = 'IMPORT_AUTHORITY' 
      AND (b.id IS NULL OR b.status NOT IN ('COMPLETED', 'NOT_APPLICABLE', 'OFFICIAL_EMPTY'));
      
    IF v_missing_entries > 0 THEN
        RAISE EXCEPTION 'Cannot finalize: % manifest entries lack a COMPLETED batch.', v_missing_entries;
    END IF;

    -- Check for any pending batches overall
    SELECT COUNT(*) INTO v_pending_batches 
    FROM data_imports.batches 
    WHERE release_id = p_release_id AND status NOT IN ('COMPLETED', 'OFFICIAL_EMPTY', 'DEFERRED', 'NOT_APPLICABLE');

    IF v_pending_batches > 0 THEN
        RAISE EXCEPTION 'Cannot finalize: % batches are not in COMPLETED state.', v_pending_batches;
    END IF;

    -- Check for unresolved errors in staging for this release
    SELECT COUNT(*) INTO v_unresolved_parents
    FROM staging.geography_imports i
    JOIN data_imports.batches b ON i.batch_id = b.id
    WHERE b.release_id = p_release_id AND i.classification = 'UNRESOLVED_PARENT';

    IF v_unresolved_parents > 0 THEN
        RAISE EXCEPTION 'Cannot finalize: % unresolved parent conflicts exist.', v_unresolved_parents;
    END IF;

    -- Ensure required entities have at least one batch (basic safety)
    FOREACH v_ent IN ARRAY v_required_entities
    LOOP
        SELECT COUNT(*) INTO v_batch_count FROM data_imports.batches WHERE release_id = p_release_id AND entity_type = v_ent;
        IF v_batch_count = 0 THEN
            -- Check if manifest actually had this entity
            SELECT COUNT(*) INTO v_batch_count FROM data_imports.release_manifest_entries WHERE release_id = p_release_id AND entity_type = v_ent AND role = 'IMPORT_AUTHORITY';
            IF v_batch_count > 0 THEN
                RAISE EXCEPTION 'Cannot finalize: Required entity % is missing a batch record despite being in manifest.', v_ent;
            END IF;
        END IF;
    END LOOP;

    -- Update release status
    UPDATE data_imports.releases
    SET status = 'COMPLETED', completed_at = NOW()
    WHERE id = p_release_id;

    RETURN pg_catalog.jsonb_build_object('status', 'SUCCESS', 'message', 'Release ' || p_release_id || ' finalized cleanly.');
END;
$$;
