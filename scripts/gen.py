import re
with open('D:/NAMISH_GLOBAL_CONTROL/r16_cli_dryrun_20260901_183500/supabase/migrations/20260901000003_r16_promotion_rehearsal.sql', 'r') as f:
    sql = f.read()

sql = sql.replace('LGD_CORE_R16_REHEARSAL', 'LGD_CORE_PROMOTION')

new_end = r'''    UPDATE data_imports.geography_releases 
    SET execution_artifact = jsonb_build_object(
        'timestamp', now(),
        'districts_inserted', COALESCE(i_dist,0),
        'subdistricts_inserted', COALESCE(i_subdist,0),
        'blocks_inserted', COALESCE(i_block,0),
        'block_districts_inserted', COALESCE(i_rel,0)
    )
    WHERE id = v_release_id;
END;
;
COMMIT;'''

sql = re.sub(r"RAISE EXCEPTION 'SUCCESS[\s\S]+ROLLBACK;", new_end, sql)

assertions = r'''    DECLARE
        c_staging int;
        v_status text;
        v_batches int;
        v_staged int;
    BEGIN
        SELECT status INTO v_status FROM data_imports.geography_releases WHERE id = v_release_id;
        IF v_status != 'STAGED' THEN RAISE EXCEPTION 'Release not STAGED: %', v_status; END IF;
        
        SELECT count(*) INTO v_batches FROM data_imports.batches WHERE release_id = v_release_id;
        SELECT count(*) INTO v_staged FROM data_imports.batches WHERE release_id = v_release_id AND status = 'STAGED';
        IF v_batches != 144 THEN RAISE EXCEPTION 'Batches != 144'; END IF;
        IF v_staged != 143 THEN RAISE EXCEPTION 'Staged Batches != 143'; END IF;
        
        SELECT count(*) INTO c_staging FROM staging.geography_imports WHERE release_id = v_release_id;
        IF c_staging != 15250 THEN RAISE EXCEPTION 'Staging rows != 15250'; END IF;
    END;

    SELECT count(*) INTO c_state FROM catalog.geography_units WHERE geography_level_id = state_lvl;
    SELECT count(*) INTO c_dist FROM catalog.geography_units WHERE geography_level_id = district_lvl;
    SELECT count(*) INTO c_subdist FROM catalog.geography_units WHERE geography_level_id = subdistrict_lvl;
    SELECT count(*) INTO c_block FROM catalog.development_blocks;
    SELECT count(*) INTO c_rel FROM catalog.block_districts;
    IF c_state != 36 OR c_dist != 0 OR c_subdist != 0 OR c_block != 0 OR c_rel != 0 THEN
        RAISE EXCEPTION 'Canonical baseline not clean! %, %, %, %, %', c_state, c_dist, c_subdist, c_block, c_rel;
    END IF;
'''

old_stmt = "SELECT id INTO subdistrict_lvl FROM catalog.geography_levels WHERE level_key = 'SUB_DISTRICT';"
sql = sql.replace(old_stmt, old_stmt + "\n\n" + assertions)

with open('D:/NAMISH_GLOBAL_CONTROL/r16_cli_commit_20260901_203200/supabase/migrations/20260901000003_r16_promotion_commit.sql', 'w') as f:
    f.write(sql)
print('Done!')
