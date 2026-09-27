-- 20260827000028_post_office_review_blocks.sql

ALTER TABLE catalog.post_office_identity_reviews
ADD COLUMN blocks_identity_promotion BOOLEAN DEFAULT false,
ADD COLUMN blocks_coordinate_resolution BOOLEAN DEFAULT false,
ADD COLUMN blocks_release BOOLEAN DEFAULT false;

-- Add check to finalizer
CREATE OR REPLACE FUNCTION data_imports.rpc_finalize_geography_release(p_release_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_missing_entries INT;
    v_extra_batches INT;
    v_invalid_state_batches INT;
    v_unresolved_parents INT;
    v_blocking_reviews INT;
BEGIN
    -- Check 1: Must be in Phase B
    IF NOT EXISTS (SELECT 1 FROM data_imports.releases WHERE id = p_release_id AND status = 'PROMOTING') THEN
        RAISE EXCEPTION 'Cannot finalize: Release is not in PROMOTING state.';
    END IF;

    -- Check 2: All manifest outputs must be COMPLETED
    WITH expected AS (
        SELECT value->>'logical_output' AS logical_batch_key
        FROM data_imports.releases r,
        jsonb_array_elements(r.manifest->'entries') AS entry,
        jsonb_array_elements(entry->'logical_outputs') AS value
        WHERE r.id = p_release_id
    )
    SELECT count(*)
    INTO v_missing_entries
    FROM expected e
    LEFT JOIN data_imports.batches b 
      ON b.release_id = p_release_id 
      AND b.logical_batch_key = e.logical_batch_key 
      AND b.status IN ('COMPLETED', 'OFFICIAL_EMPTY')
    WHERE b.id IS NULL;

    IF v_missing_entries > 0 THEN
        RAISE EXCEPTION 'Cannot finalize: % required logical keys are missing or not completed.', v_missing_entries;
    END IF;

    -- Check 3: No unregistered batches exist
    WITH expected AS (
        SELECT value->>'logical_output' AS logical_batch_key
        FROM data_imports.releases r,
        jsonb_array_elements(r.manifest->'entries') AS entry,
        jsonb_array_elements(entry->'logical_outputs') AS value
        WHERE r.id = p_release_id
    )
    SELECT count(*)
    INTO v_extra_batches
    FROM data_imports.batches b
    LEFT JOIN expected e ON b.logical_batch_key = e.logical_batch_key
    WHERE b.release_id = p_release_id AND e.logical_batch_key IS NULL;

    IF v_extra_batches > 0 THEN
        RAISE EXCEPTION 'Cannot finalize: % extra registered batches found.', v_extra_batches;
    END IF;

    -- Check 4: No batch in error or pending state
    SELECT count(*)
    INTO v_invalid_state_batches
    FROM data_imports.batches
    WHERE release_id = p_release_id AND status NOT IN ('COMPLETED', 'OFFICIAL_EMPTY');

    IF v_invalid_state_batches > 0 THEN
        RAISE EXCEPTION 'Cannot finalize: % batches are not COMPLETED or OFFICIAL_EMPTY.', v_invalid_state_batches;
    END IF;

    -- Check 5: No unresolved parent hierarchy reviews
    SELECT count(*)
    INTO v_unresolved_parents
    FROM staging.geography_imports
    WHERE release_id = p_release_id AND classification = 'PARENT_CONFLICT';

    IF v_unresolved_parents > 0 THEN
        RAISE EXCEPTION 'Cannot finalize: % unresolved reviews exist in staging.', v_unresolved_parents;
    END IF;

    -- Check 6: No blocking postal reviews
    SELECT count(*)
    INTO v_blocking_reviews
    FROM catalog.post_office_identity_reviews
    WHERE release_id = p_release_id AND status != 'RESOLVED' AND blocks_release = true;

    IF v_blocking_reviews > 0 THEN
        RAISE EXCEPTION 'Cannot finalize: % unresolved blocking postal reviews exist.', v_blocking_reviews;
    END IF;

    -- Finalize
    UPDATE data_imports.releases 
    SET status = 'COMPLETE' 
    WHERE id = p_release_id;

    RETURN pg_catalog.jsonb_build_object('status', 'SUCCESS', 'message', 'Release finalized cleanly.');
END;
$$;
REVOKE ALL ON FUNCTION data_imports.rpc_finalize_geography_release FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION data_imports.rpc_finalize_geography_release TO service_role;
