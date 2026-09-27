-- R16 Metadata Finalization
-- Sets all 143 STAGED batches to FINALIZED.
-- Zero geography DML. Release status stays PROMOTED.
DO $$
DECLARE
    v_release_id uuid := '5fac63d7-0101-43c5-8867-bd75ff609861';
    v_finalized int;
    v_release_status text;
BEGIN
    SELECT status INTO v_release_status FROM data_imports.releases WHERE id = v_release_id;
    IF v_release_status != 'PROMOTED' THEN
        RAISE EXCEPTION 'Release not PROMOTED: %', v_release_status;
    END IF;

    UPDATE data_imports.batches
    SET status = 'FINALIZED', completed_at = now()
    WHERE release_id = v_release_id AND status = 'STAGED';
    GET DIAGNOSTICS v_finalized = ROW_COUNT;

    IF v_finalized != 143 THEN
        RAISE EXCEPTION 'Expected 143 batches finalized, got: %', v_finalized;
    END IF;

    RAISE NOTICE 'R16 FINALIZED: % batches set to FINALIZED. Release remains PROMOTED.', v_finalized;
END;
$$;
