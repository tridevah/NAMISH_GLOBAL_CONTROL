BEGIN;
SELECT catalog.create_business_release('v8.2.0-test-fail', false);
SELECT catalog.create_business_release('v8.2.0-test-fail', true); -- Should crash the entire script!
ROLLBACK;
