BEGIN;

DO $$
DECLARE
    v_draft_res1 JSONB;
    v_draft_res2 JSONB;
    v_draft_id1 UUID;
    v_draft_id2 UUID;
    v_baseline_id UUID;
    v_pub1 JSONB;
    v_pub2 JSONB;
BEGIN
    SELECT id INTO v_baseline_id 
    FROM catalog.catalog_releases 
    WHERE status = 'PUBLISHED' 
    ORDER BY release_sequence DESC NULLS LAST 
    LIMIT 1;

    -- Create drafts (simulating two users creating drafts concurrently against the same baseline)
    SELECT catalog.create_business_release('v8.4.0-test1', false) INTO v_draft_res1;
    v_draft_id1 := (v_draft_res1->>'release_id')::uuid;

    SELECT catalog.create_business_release('v8.4.0-test2', false) INTO v_draft_res2;
    v_draft_id2 := (v_draft_res2->>'release_id')::uuid;

    -- User 1 publishes successfully (passing the expected baseline)
    SELECT catalog.publish_draft_release(v_draft_id1, v_baseline_id) INTO v_pub1;
    
    -- User 2 attempts to publish after User 1, passing the SAME old baseline
    SELECT catalog.publish_draft_release(v_draft_id2, v_baseline_id) INTO v_pub2;

    -- Create a temporary table to hold the results so we can select them out
    CREATE TEMP TABLE tmp_results (pub1 JSONB, pub2 JSONB) ON COMMIT DROP;
    INSERT INTO tmp_results VALUES (v_pub1, v_pub2);

END $$;

SELECT jsonb_pretty(pub1) as publish_1, jsonb_pretty(pub2) as publish_2
FROM tmp_results;

ROLLBACK;
