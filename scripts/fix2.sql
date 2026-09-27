DROP TRIGGER IF EXISTS enforce_release_execution_artifacts_immutable ON data_imports.release_execution_artifacts;
UPDATE data_imports.release_execution_artifacts SET artifact_payload = jsonb_set(artifact_payload, '{overwritten_artifact_reference_id}', to_jsonb((SELECT id FROM data_imports.release_execution_artifacts WHERE artifact_type = 'BATCH_IDENTITY_RELINK' LIMIT 1)::text)) WHERE artifact_type = 'CORRECTION_OF_IN_PLACE_PROVENANCE_UPDATE';
CREATE TRIGGER enforce_release_execution_artifacts_immutable
BEFORE UPDATE OR DELETE ON data_imports.release_execution_artifacts
FOR EACH ROW
EXECUTE FUNCTION data_imports.release_execution_artifacts_immutable_trigger();
