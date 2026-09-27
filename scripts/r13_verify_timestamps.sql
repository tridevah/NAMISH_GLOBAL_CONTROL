BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY;

WITH r13 AS (SELECT id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R13')
SELECT
    (SELECT count(*) FROM staging.geography_imports WHERE release_id = (SELECT id FROM r13)) AS staging_by_release,
    (SELECT count(*) FROM staging.geography_imports s JOIN data_imports.batches b ON s.batch_id = b.id WHERE b.release_id = (SELECT id FROM r13)) AS staging_by_batch,
    (SELECT max(created_at) FROM staging.geography_imports WHERE release_id = (SELECT id FROM r13)) AS last_insert,
    (SELECT max(completed_at) FROM data_imports.batches WHERE release_id = (SELECT id FROM r13)) AS last_batch_change,
    (SELECT created_at FROM data_imports.release_execution_artifacts WHERE release_id = (SELECT id FROM r13) ORDER BY created_at DESC LIMIT 1) AS artifact_timestamp;

COMMIT;
