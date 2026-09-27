UPDATE data_imports.releases
SET status = 'INVALIDATED',
    invalidated_at = NOW(),
    invalidated_reason = 'INVALIDATED_DUPLICATE_BLOCK_NAME_HEADER_COLLISION'
WHERE release_name = 'LGD_20260826_CORE_R15' RETURNING id;

INSERT INTO data_imports.release_execution_artifacts (release_id, artifact_type, content)
SELECT id, 'LIFECYCLE_EVENT', '{"event": "INVALIDATED_DUPLICATE_BLOCK_NAME_HEADER_COLLISION"}'::jsonb
FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R15';

