BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY;

WITH r13 AS (SELECT id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R13')
SELECT 'STAGING_BY_RELEASE', count(*) FROM staging.geography_imports WHERE release_id = (SELECT id FROM r13);

WITH r13 AS (SELECT id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R13')
SELECT 'STAGING_BY_BATCH', count(*) FROM staging.geography_imports s
JOIN data_imports.batches b ON s.batch_id = b.id
WHERE b.release_id = (SELECT id FROM r13);

WITH r13 AS (SELECT id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R13')
SELECT entity_type, count(*) FROM staging.geography_imports WHERE release_id = (SELECT id FROM r13) GROUP BY entity_type;

WITH r13 AS (SELECT id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R13')
SELECT status, count(*) FROM data_imports.batches WHERE release_id = (SELECT id FROM r13) GROUP BY status;

WITH r13 AS (SELECT id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R13')
SELECT logical_batch_key FROM data_imports.batches WHERE release_id = (SELECT id FROM r13) AND status = 'STAGED' ORDER BY completed_at DESC LIMIT 1;

WITH r13 AS (SELECT id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R13')
SELECT count(*) FROM data_imports.canonical_writes WHERE release_id = (SELECT id FROM r13);

COMMIT;
