with open('D:/NAMISH_GLOBAL_CONTROL/r16_cli_commit_20260901_203200/supabase/migrations/20260901000003_r16_promotion_commit.sql', 'r') as f:
    content = f.read()

# Remove the release status pre-check sub-block since the release will be STAGED by the separate prep migration
# Replace the STAGED check sub-block with just staging row count check
old_assert = """    DECLARE
        c_staging int;
        v_status text;
        v_batches int;
        v_staged int;
    BEGIN
        SELECT status INTO v_status FROM data_imports.releases WHERE id = v_release_id;
        IF v_status != 'STAGED' THEN RAISE EXCEPTION 'Release not STAGED: %', v_status; END IF;
        
        SELECT count(*) INTO v_batches FROM data_imports.batches WHERE release_id = v_release_id;
        SELECT count(*) INTO v_staged FROM data_imports.batches WHERE release_id = v_release_id AND status = 'STAGED';
        IF v_batches != 144 THEN RAISE EXCEPTION 'Batches != 144'; END IF;
        IF v_staged != 143 THEN RAISE EXCEPTION 'Staged Batches != 143'; END IF;
        
        SELECT count(*) INTO c_staging FROM staging.geography_imports WHERE release_id = v_release_id;
        IF c_staging != 15250 THEN RAISE EXCEPTION 'Staging rows != 15250'; END IF;
    END;"""

new_assert = """    DECLARE
        c_staging int;
        v_status text;
        v_batches int;
        v_staged int;
    BEGIN
        SELECT status INTO v_status FROM data_imports.releases WHERE id = v_release_id;
        IF v_status != 'STAGED' THEN RAISE EXCEPTION 'Release not STAGED: %', v_status; END IF;
        
        SELECT count(*) INTO v_batches FROM data_imports.batches WHERE release_id = v_release_id;
        IF v_batches != 144 THEN RAISE EXCEPTION 'Batches != 144, got: ' || v_batches; END IF;
        
        SELECT count(*) INTO v_staged FROM data_imports.batches WHERE release_id = v_release_id AND status = 'STAGED';
        IF v_staged != 143 THEN RAISE EXCEPTION 'Staged Batches != 143, got: ' || v_staged; END IF;
        
        SELECT count(*) INTO c_staging FROM staging.geography_imports WHERE release_id = v_release_id;
        IF c_staging != 15250 THEN RAISE EXCEPTION 'Staging rows != 15250, got: ' || c_staging; END IF;
    END;"""

content = content.replace(old_assert, new_assert)

# Fix the artifact evidence to use the correct table/approach (simple notice at end)
old_update = """        UPDATE data_imports.releases 
    SET execution_artifact = jsonb_build_object(
        'timestamp', now(),
        'districts_inserted', COALESCE(i_dist,0),
        'subdistricts_inserted', COALESCE(i_subdist,0),
        'blocks_inserted', COALESCE(i_block,0),
        'block_districts_inserted', COALESCE(i_rel,0)
    )
    WHERE id = v_release_id;"""

new_update = """    INSERT INTO data_imports.release_execution_artifacts 
        (release_id, artifact_type, artifact_payload)
    VALUES (
        v_release_id, 
        'PROMOTION_EVIDENCE',
        jsonb_build_object(
            'timestamp', now(),
            'districts_inserted', COALESCE(i_dist,0),
            'subdistricts_inserted', COALESCE(i_subdist,0),
            'blocks_inserted', COALESCE(i_block,0),
            'block_districts_inserted', COALESCE(i_rel,0),
            'promotion_sha256', 'CC61A483644F966E420B2753447311495EB2E12F13B36A4551D06D18DEFC0F17'
        )
    );"""

content = content.replace(old_update, new_update)

with open('D:/NAMISH_GLOBAL_CONTROL/r16_cli_commit_20260901_203200/supabase/migrations/20260901000003_r16_promotion_commit.sql', 'w') as f:
    f.write(content)
print('Fixed.')
