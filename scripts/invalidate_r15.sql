UPDATE data_imports.releases
SET status = 'INVALIDATED',
    artifacts = COALESCE(artifacts, '[]'::jsonb) || '["INVALIDATED_DUPLICATE_BLOCK_NAME_HEADER_COLLISION"]'::jsonb
WHERE release_name = 'LGD_20260826_CORE_R15';
