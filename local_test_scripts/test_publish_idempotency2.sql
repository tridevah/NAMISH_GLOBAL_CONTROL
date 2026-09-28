BEGIN;

DO $$
DECLARE
    v_draft_res JSONB;
    v_draft_id UUID;
    v_baseline_id UUID;
    v_pub1 JSONB;
    v_pub2 JSONB;
BEGIN
    SELECT id INTO v_baseline_id 
    FROM catalog.catalog_releases 
    WHERE status = 'PUBLISHED' 
    ORDER BY release_sequence DESC NULLS LAST 
    LIMIT 1;

    SELECT catalog.create_business_release('v8.3.0-test-idempotency', false) INTO v_draft_res;
    v_draft_id := (v_draft_res->>'release_id')::uuid;

    SELECT catalog.publish_draft_release(v_draft_id, v_baseline_id) INTO v_pub1;
    SELECT catalog.publish_draft_release(v_draft_id, v_baseline_id) INTO v_pub2;

    -- Create a temporary table to hold the results so we can select them out
    CREATE TEMP TABLE tmp_results (pub1 JSONB, pub2 JSONB, matched BOOLEAN) ON COMMIT DROP;
    INSERT INTO tmp_results VALUES (
        v_pub1, 
        v_pub2, 
        (v_pub1->>'event_id' = v_pub2->>'event_id' AND v_pub1->>'sequence' = v_pub2->>'sequence')
    );

END $$;

SELECT jsonb_pretty(pub1) as publish_1, jsonb_pretty(pub2) as publish_2, matched as exact_match 
FROM tmp_results;

ROLLBACK;
