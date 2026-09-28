BEGIN;

DO $$
DECLARE
    v_draft_res JSONB;
    v_draft_id UUID;
    v_baseline_id UUID;
    v_pub1 JSONB;
    v_pub2 JSONB;
BEGIN
    -- Get baseline to pass to publish
    SELECT id INTO v_baseline_id 
    FROM catalog.catalog_releases 
    WHERE status = 'PUBLISHED' 
    ORDER BY release_sequence DESC NULLS LAST 
    LIMIT 1;

    -- Create draft
    SELECT catalog.create_business_release('v8.3.0-test-idempotency', false) INTO v_draft_res;
    v_draft_id := (v_draft_res->>'release_id')::uuid;

    -- First publish
    SELECT catalog.publish_draft_release(v_draft_id, v_baseline_id) INTO v_pub1;
    
    -- Second publish (retry)
    SELECT catalog.publish_draft_release(v_draft_id, v_baseline_id) INTO v_pub2;

    -- Output results
    RAISE NOTICE 'Publish 1: %', jsonb_pretty(v_pub1);
    RAISE NOTICE 'Publish 2: %', jsonb_pretty(v_pub2);
    
    IF v_pub1->>'event_id' = v_pub2->>'event_id' AND v_pub1->>'sequence' = v_pub2->>'sequence' THEN
        RAISE NOTICE 'SUCCESS: Event ID and sequence match exactly!';
    ELSE
        RAISE EXCEPTION 'MISMATCH: Event ID or sequence differ!';
    END IF;
END $$;

ROLLBACK;
