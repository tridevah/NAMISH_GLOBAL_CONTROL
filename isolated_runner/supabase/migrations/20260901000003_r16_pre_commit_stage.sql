-- R16 Pre-Commit Metadata Prep: Transition release LGD_20260826_CORE_R16 to STAGED
-- Actual verified remote state: 143 batches all STAGED, 0 OFFICIAL_EMPTY
-- Metadata-only: no canonical or staging data DML
DO $$
DECLARE
    v_release_id uuid := '5fac63d7-0101-43c5-8867-bd75ff609861';
    v_current_status text;
    v_batch_count int;
    v_staged_count int;
BEGIN
    SELECT status INTO v_current_status FROM data_imports.releases WHERE id = v_release_id;
    RAISE NOTICE 'Release current status: %', v_current_status;

    IF v_current_status NOT IN ('PENDING', 'STAGED') THEN
        RAISE EXCEPTION 'Release not in transitionable state: %', v_current_status;
    END IF;

    SELECT count(*) INTO v_batch_count FROM data_imports.batches WHERE release_id = v_release_id;
    IF v_batch_count != 143 THEN
        RAISE EXCEPTION 'Expected 143 batches, found: %', v_batch_count;
    END IF;

    SELECT count(*) INTO v_staged_count FROM data_imports.batches WHERE release_id = v_release_id AND status = 'STAGED';
    IF v_staged_count != 143 THEN
        RAISE EXCEPTION 'Expected 143 STAGED batches, found: %', v_staged_count;
    END IF;

    UPDATE data_imports.releases SET status = 'STAGED', completed_at = now() WHERE id = v_release_id AND status = 'PENDING';
    RAISE NOTICE 'Release transitioned: PENDING -> STAGED';
    
    RAISE NOTICE 'Pre-commit metadata prep complete. Release=STAGED, Batches=143/143 STAGED.';
END;
$$;
