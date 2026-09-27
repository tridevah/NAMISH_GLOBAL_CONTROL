BEGIN;

-- Block UPDATE and DELETE with a BEFORE trigger
CREATE OR REPLACE FUNCTION data_imports.release_execution_artifacts_immutable_trigger()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
BEGIN
    RAISE EXCEPTION 'RELEASE_EXECUTION_ARTIFACT_IMMUTABLE';
END;
$$;

CREATE TRIGGER enforce_release_execution_artifacts_immutable
BEFORE UPDATE OR DELETE ON data_imports.release_execution_artifacts
FOR EACH ROW
EXECUTE FUNCTION data_imports.release_execution_artifacts_immutable_trigger();

-- Prevent direct mutation by PUBLIC, anon and authenticated
REVOKE UPDATE, DELETE ON data_imports.release_execution_artifacts FROM PUBLIC, anon, authenticated;

-- Append a new compensating provenance event recording truthfully
INSERT INTO data_imports.release_execution_artifacts (release_id, artifact_type, artifact_payload)
VALUES (
    'b3573f9b-1eff-47d5-8cdf-fba3eba74b19',
    'CORRECTION_OF_IN_PLACE_PROVENANCE_UPDATE',
    jsonb_build_object(
        'original_v1_hash', '311b1c99c768a6bc72b18084ead968a333e994b946a3a640a16323dbff8a8e9c',
        'lost_unexecuted_candidate_hash', '768cc2dc663c7723e75ca99198f60873d3c54fccb8b1fa40a1d6bda2e101c9f6',
        'actual_audited_v2_hash', '4f177ff1263bb1908408b576f2781fcee4dead86f58e9b0faa7a1c45d44d0e5d',
        'first_execution_processed_keys', 259,
        'corrective_v2_processed_keys', 204,
        'existing_staged_observations', 4459838,
        'canonical_writes', 0,
        'reason', 'CORRECTION_OF_IN_PLACE_PROVENANCE_UPDATE',
        'overwritten_artifact_reference_id', (SELECT id FROM data_imports.release_execution_artifacts WHERE release_id = 'b3573f9b-1eff-47d5-8cdf-fba3eba74b19' AND artifact_type = 'BATCH_IDENTITY_RELINK' LIMIT 1)
    )
);

COMMIT;
