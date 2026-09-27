BEGIN;
SELECT max(created_at) AS last_row_insert FROM staging.geography_imports WHERE release_id = 'b1300000-0000-0000-0000-000000000000';
SELECT created_at AS artifact_insert FROM data_imports.release_execution_artifacts WHERE release_id = 'b1300000-0000-0000-0000-000000000000' AND artifact_type = 'INVALIDATED_OBSERVATION_IDENTITY_AND_STATUS_SEMANTICS';
COMMIT;
