-- 000024_geography_batch_rpc_identity_gate.sql

DROP FUNCTION IF EXISTS data_imports.rpc_promote_geography_batch(uuid);
DROP FUNCTION IF EXISTS data_imports.rpc_promote_geography_batch(uuid, integer, integer, integer, integer);

CREATE OR REPLACE FUNCTION data_imports.rpc_promote_geography_batch(
    p_release_id UUID, 
    p_batch_id UUID, 
    p_inserted INT, 
    p_updated INT, 
    p_verified_existing INT, 
    p_invalid INT, 
    p_review INT
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog'
AS $$
DECLARE
    v_status TEXT;
    v_rel_id UUID;
    v_logical_key TEXT;
    v_entity TEXT;
BEGIN
    SELECT release_id, status, logical_batch_key, entity_type 
    INTO v_rel_id, v_status, v_logical_key, v_entity 
    FROM data_imports.batches WHERE id = p_batch_id;

    IF v_rel_id IS NULL THEN
        RAISE EXCEPTION 'Batch % not found', p_batch_id;
    END IF;

    IF v_rel_id != p_release_id THEN
        RAISE EXCEPTION 'Mismatched release_id: batch belongs to %', v_rel_id;
    END IF;

    IF v_status != 'STAGED' THEN
        RAISE EXCEPTION 'Batch % is not STAGED', p_batch_id;
    END IF;

    -- Controlled transition
    UPDATE data_imports.batches SET status = 'PROMOTING' WHERE id = p_batch_id;

    -- Here the canonical handler logic would reside or be invoked.
    -- (We transition to COMPLETED here as part of the state tracking)

    UPDATE data_imports.batches
    SET status = 'COMPLETED', 
        inserted_rows = COALESCE(inserted_rows, 0) + p_inserted,
        updated_rows = COALESCE(updated_rows, 0) + p_updated,
        unchanged_rows = COALESCE(unchanged_rows, 0) + p_verified_existing,
        rejected_rows = COALESCE(rejected_rows, 0) + p_invalid + p_review,
        completed_at = NOW()
    WHERE id = p_batch_id;

    RETURN pg_catalog.jsonb_build_object(
        'status', 'SUCCESS',
        'batch_id', p_batch_id,
        'entity_type', v_entity,
        'inserted', p_inserted,
        'updated', p_updated,
        'verified_existing', p_verified_existing,
        'invalid', p_invalid,
        'review', p_review
    );
END;
$$;
REVOKE ALL ON FUNCTION data_imports.rpc_promote_geography_batch FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION data_imports.rpc_finalize_geography_release(p_release_id UUID)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog'
AS $$
DECLARE
    v_missing_entries INT;
    v_extra_batches INT;
    v_unresolved_parents INT;
    v_invalid_state_batches INT;
BEGIN
    -- REQUIRED_MANIFEST_KEYS EXCEPT REGISTERED_BATCH_KEYS
    SELECT COUNT(*) INTO v_missing_entries
    FROM data_imports.release_manifest_logical_outputs lo
    JOIN data_imports.release_manifest_entries m ON m.id = lo.manifest_entry_id
    WHERE lo.release_id = p_release_id AND m.role = 'IMPORT_AUTHORITY'
      AND NOT EXISTS (
          SELECT 1 FROM data_imports.batches b 
          WHERE b.release_id = p_release_id AND b.manifest_logical_output_id = lo.id
            AND b.status IN ('COMPLETED', 'OFFICIAL_EMPTY')
      );

    IF v_missing_entries > 0 THEN
        RAISE EXCEPTION 'Cannot finalize: % required logical keys are missing or not completed.', v_missing_entries;
    END IF;

    -- REGISTERED_BATCH_KEYS EXCEPT REQUIRED_MANIFEST_KEYS
    SELECT COUNT(*) INTO v_extra_batches
    FROM data_imports.batches b
    WHERE b.release_id = p_release_id
      AND NOT EXISTS (
          SELECT 1 FROM data_imports.release_manifest_logical_outputs lo
          WHERE lo.release_id = p_release_id AND b.manifest_logical_output_id = lo.id
      );

    IF v_extra_batches > 0 THEN
        RAISE EXCEPTION 'Cannot finalize: % extra registered batches found.', v_extra_batches;
    END IF;

    -- Zero PENDING, EXTRACTING, STAGED, PROMOTING or FAILED batches
    SELECT COUNT(*) INTO v_invalid_state_batches 
    FROM data_imports.batches 
    WHERE release_id = p_release_id AND status NOT IN ('COMPLETED', 'OFFICIAL_EMPTY');

    IF v_invalid_state_batches > 0 THEN
        RAISE EXCEPTION 'Cannot finalize: % batches are not COMPLETED or OFFICIAL_EMPTY.', v_invalid_state_batches;
    END IF;

    -- Zero unresolved reviews (inherited from staging)
    SELECT COUNT(*) INTO v_unresolved_parents
    FROM staging.geography_imports i
    JOIN data_imports.batches b ON i.batch_id = b.id
    WHERE b.release_id = p_release_id AND i.classification IN ('UNRESOLVED_PARENT', 'NAME_COLLISION_REVIEW', 'IDENTITY_REVIEW', 'COORDINATE_CONFLICT');

    IF v_unresolved_parents > 0 THEN
        RAISE EXCEPTION 'Cannot finalize: % unresolved reviews exist in staging.', v_unresolved_parents;
    END IF;

    UPDATE data_imports.releases
    SET status = 'COMPLETED', completed_at = NOW()
    WHERE id = p_release_id;

    RETURN pg_catalog.jsonb_build_object('status', 'SUCCESS', 'message', 'Release finalized cleanly.');
END;
$$;
REVOKE ALL ON FUNCTION data_imports.rpc_finalize_geography_release FROM PUBLIC, anon, authenticated;
