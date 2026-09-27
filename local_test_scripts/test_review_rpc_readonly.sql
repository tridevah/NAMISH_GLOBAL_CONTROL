-- Read-only test of review RPC against the published sequence-5 release
-- Uses ca7c5ea6-2f52-44de-bd42-f46b253a4d63 (cleanup draft, UNPUBLISHED)
-- Does NOT mutate anything

BEGIN READ ONLY;

-- Test 1: Verify published release id and sequence
SELECT id, version, status, release_sequence 
FROM catalog.catalog_releases 
WHERE status = 'PUBLISHED'
ORDER BY created_at DESC
LIMIT 3;

-- Test 2: Run get_release_review on existing draft (read-only call)
SELECT public.get_release_review('ca7c5ea6-2f52-44de-bd42-f46b253a4d63'::uuid);

-- Test 3: Verify get_release_review on unknown id returns error, not silent failure
SELECT public.get_release_review('00000000-0000-0000-0000-000000000000'::uuid);

ROLLBACK;
