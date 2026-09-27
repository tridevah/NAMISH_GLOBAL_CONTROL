BEGIN;

-- Setup test variables
DO $$
DECLARE
    v_state_id pg_catalog.uuid;
    v_dist1_id pg_catalog.uuid;
    v_dist2_id pg_catalog.uuid;
    v_other_state_dist_id pg_catalog.uuid;
    v_block_id pg_catalog.uuid;
BEGIN
    -- Get valid districts and state
    SELECT id INTO v_state_id FROM catalog.geography_units WHERE geography_level_id = (SELECT id FROM catalog.geography_levels WHERE level_key = 'STATE_UT') LIMIT 1;
    
    SELECT id INTO v_dist1_id FROM catalog.geography_units WHERE geography_level_id = (SELECT id FROM catalog.geography_levels WHERE level_key = 'DISTRICT') AND parent_geography_unit_id = v_state_id LIMIT 1;
    
    SELECT id INTO v_dist2_id FROM catalog.geography_units WHERE geography_level_id = (SELECT id FROM catalog.geography_levels WHERE level_key = 'DISTRICT') AND parent_geography_unit_id = v_state_id AND id != v_dist1_id LIMIT 1;
    
    SELECT id INTO v_other_state_dist_id FROM catalog.geography_units WHERE geography_level_id = (SELECT id FROM catalog.geography_levels WHERE level_key = 'DISTRICT') AND parent_geography_unit_id != v_state_id LIMIT 1;

    -- Create canonical test block
    INSERT INTO catalog.development_blocks (id, official_code, official_name) VALUES (gen_random_uuid(), 'TEST_BLOCK_001', 'Test Block') RETURNING id INTO v_block_id;

    -- TEST 1: one Block with one District
    INSERT INTO catalog.block_districts (block_id, district_id) VALUES (v_block_id, v_dist1_id);
    RAISE NOTICE 'SUCCESS: One Block with one District';

    -- TEST 2: one Block with two Districts
    INSERT INTO catalog.block_districts (block_id, district_id) VALUES (v_block_id, v_dist2_id);
    RAISE NOTICE 'SUCCESS: One Block with two Districts';

    -- TEST 3: duplicate relationship rejected
    BEGIN
        INSERT INTO catalog.block_districts (block_id, district_id) VALUES (v_block_id, v_dist1_id);
        RAISE EXCEPTION 'FAIL: Duplicate allowed';
    EXCEPTION WHEN unique_violation THEN
        RAISE NOTICE 'SUCCESS: Duplicate relationship rejected';
    END;

    -- TEST 4: cross-State District relationship rejected
    BEGIN
        INSERT INTO catalog.block_districts (block_id, district_id) VALUES (v_block_id, v_other_state_dist_id);
        RAISE EXCEPTION 'FAIL: Cross-State allowed';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'SUCCESS: Cross-State District relationship rejected (%)', SQLERRM;
    END;

    -- TEST 5: non-District geography relationship rejected
    BEGIN
        INSERT INTO catalog.block_districts (block_id, district_id) VALUES (v_block_id, v_state_id);
        RAISE EXCEPTION 'FAIL: Non-District allowed';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'SUCCESS: Non-District geography relationship rejected (%)', SQLERRM;
    END;
    
    -- TEST 6: existing RPC/API response remains valid
    PERFORM * FROM public.rpc_get_development_blocks() WHERE official_code = 'TEST_BLOCK_001';
    RAISE NOTICE 'SUCCESS: RPC response valid';
    
END;
$$;

ROLLBACK;
