BEGIN;

-- Test 1: Existing sequence-5 review finds its actual ERP SUCCESS delivery
SELECT jsonb_pretty(public.get_release_review('b806207a-aa82-4e43-adc1-c4ee2670f85d'::uuid)) as review_seq5;

-- Test 2: Review ca7c5ea6 (cleanup draft) vs seq-5 baseline (should show modified units)
SELECT jsonb_pretty(public.get_release_review('ca7c5ea6-2f52-44de-bd42-f46b253a4d63'::uuid)) as review_draft;

-- Test 3: Concurrent/retry test
-- We will call create_business_release twice with the SAME version to test idempotency
SELECT catalog.create_business_release('v8.2.0-test', false) as t3a;
SELECT catalog.create_business_release('v8.2.0-test', false) as t3b;
-- Should fail because include_cleanup mismatch
-- We must catch the exception manually in plpgsql to not abort the transaction
DO $$
BEGIN
    PERFORM catalog.create_business_release('v8.2.0-test', true);
    RAISE EXCEPTION 'Should have failed on include_cleanup mismatch';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Test 3c Caught: %', SQLERRM;
END $$;

ROLLBACK;
