-- R16 PROVENANCE & METADATA FINALIZE
DO $$
DECLARE
    v_release_id uuid := '5fac63d7-0101-43c5-8867-bd75ff609861';
    v_batch_key text := 'DELHI/downloadDir2026_08_27_00_03_00_196.zip!blockofspecificState2026:08:27:00:03:00:881.xls!!BLOCK!0';
    v_batch_id uuid;
BEGIN
    -- 1. Insert OFFICIAL_EMPTY Delhi BLOCK batch
    INSERT INTO data_imports.batches 
        (release_id, logical_batch_key, entity_type, status, total_records, successful_records, failed_records, completed_at)
    VALUES 
        (v_release_id, v_batch_key, 'BLOCK', 'OFFICIAL_EMPTY', 0, 0, 0, now())
    ON CONFLICT (release_id, logical_batch_key) DO NOTHING
    RETURNING id INTO v_batch_id;

    -- 2. Change release status PROMOTED -> FINALIZED and set completed_at
    UPDATE data_imports.releases 
    SET status = 'FINALIZED', completed_at = now() 
    WHERE id = v_release_id AND status = 'PROMOTED';

    -- 3. Append PROVENANCE_RECONCILIATION evidence artifact
    INSERT INTO data_imports.release_execution_artifacts 
        (release_id, artifact_type, artifact_payload)
    VALUES (
        v_release_id, 
        'PROVENANCE_RECONCILIATION',
        jsonb_build_object(
            'timestamp', now(),
            'reconciliation_mode', 'repair_and_metadata_finalization',
            'delhi_empty_batch', v_batch_key,
            'canonical_inserts', 0,
            'canonical_updates', 0,
            'canonical_deletes', 0,
            'staging_inserts', 0
        )
    );

    RAISE NOTICE 'R16 FINALIZATION COMPLETE.';
END;
$$;
