-- Migration 000014: Core Geography R2 Sealed Manifest Correction

-- Correct pre-ingestion metadata with an append-only audit event.
-- Note: Assuming release LGD_20260826_CORE_R2 still has 0 rows based on earlier checks.
ALTER TABLE data_imports.releases
ADD COLUMN IF NOT EXISTS manifest_hash TEXT;

UPDATE data_imports.releases
SET sha256_hash = 'c9f033fd161576f0cea64fb1dcf783153546197be082ff3eede268ca7be08344',
    manifest_hash = 'c9f033fd161576f0cea64fb1dcf783153546197be082ff3eede268ca7be08344',
    invalidated_reason = COALESCE(invalidated_reason, '') || ' | AUDIT_APPEND: Original dummy hash sha256_core_r2 replaced with sealed manifest hash prior to staging due to missing manifest generation. 0 staged rows verified.'
WHERE release_name = 'LGD_20260826_CORE_R2';

-- Add a robust finalizer that requires INDIA_CORE_GEOGRAPHY scope contract
CREATE OR REPLACE FUNCTION data_imports.rpc_finalize_geography_r3(
    p_release_id pg_catalog.uuid,
    p_expected_batches INT
) RETURNS pg_catalog.jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO pg_catalog
AS $$
DECLARE
    v_actual_completed INT;
BEGIN
    SELECT COUNT(*) INTO v_actual_completed
    FROM data_imports.batches
    WHERE release_id = p_release_id AND status = 'COMPLETED';

    IF v_actual_completed < p_expected_batches THEN
        RAISE EXCEPTION 'Cannot finalize: Expected % batches but found only % COMPLETED.', p_expected_batches, v_actual_completed;
    END IF;

    -- Invoke the strict base finalizer as well
    PERFORM data_imports.rpc_finalize_geography_release(p_release_id);

    RETURN pg_catalog.jsonb_build_object('status', 'SUCCESS', 'message', 'Sealed release finalized.');
END;
$$;
REVOKE ALL ON FUNCTION data_imports.rpc_finalize_geography_r3(pg_catalog.uuid, INT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION data_imports.rpc_finalize_geography_r3(pg_catalog.uuid, INT) TO service_role;
