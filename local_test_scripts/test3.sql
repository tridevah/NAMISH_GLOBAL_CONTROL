BEGIN;
SELECT catalog.create_business_release('v8.2.0-test', false);
SELECT catalog.create_business_release('v8.2.0-test', false);
DO $$
BEGIN
    PERFORM catalog.create_business_release('v8.2.0-test', true);
    RAISE EXCEPTION 'Should have failed on include_cleanup mismatch';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Test 3c Caught: %', SQLERRM;
END $$;
ROLLBACK;
