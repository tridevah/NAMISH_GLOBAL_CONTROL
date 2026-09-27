-- Read-only test of review RPC - split into separate queries
SELECT id, version, status, release_sequence 
FROM catalog.catalog_releases 
WHERE status = 'PUBLISHED'
ORDER BY created_at DESC
LIMIT 3;
