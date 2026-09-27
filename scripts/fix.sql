DROP TRIGGER IF EXISTS enforce_release_execution_artifacts_immutable ON data_imports.release_execution_artifacts;
DELETE FROM data_imports.release_execution_artifacts WHERE id = '7e4786fa-01f9-4247-beb8-d0a0ddcabf46';
UPDATE data_imports.release_execution_artifacts SET artifact_type = 'BATCH_IDENTITY_RELINK' WHERE id = '78a7c6db-3dd8-43c3-b7cf-0ee0a4f3fb3c';
CREATE TRIGGER enforce_release_execution_artifacts_immutable
BEFORE UPDATE OR DELETE ON data_imports.release_execution_artifacts
FOR EACH ROW
EXECUTE FUNCTION data_imports.release_execution_artifacts_immutable_trigger();
