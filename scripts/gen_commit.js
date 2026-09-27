const fs = require('fs');
let rehearsal = fs.readFileSync('D:/NAMISH_GLOBAL_CONTROL/r16_cli_dryrun_20260901_183500/supabase/migrations/20260901000003_r16_promotion_rehearsal.sql', 'utf8');

rehearsal = rehearsal.replace('LGD_CORE_R16_REHEARSAL', 'LGD_CORE_PROMOTION');

let newEnd = '    UPDATE data_imports.geography_releases \\n' +
'    SET execution_artifact = jsonb_build_object(\\n' +
'        \'timestamp\', now(),\\n' +
'        \'districts_inserted\', COALESCE(i_dist,0),\\n' +
'        \'subdistricts_inserted\', COALESCE(i_subdist,0),\\n' +
'        \'blocks_inserted\', COALESCE(i_block,0),\\n' +
'        \'block_districts_inserted\', COALESCE(i_rel,0)\\n' +
'    )\\n' +
'    WHERE id = v_release_id;\\n' +
'END;\\n' +
';\\n' +
'COMMIT;';

rehearsal = rehearsal.replace(/RAISE EXCEPTION 'SUCCESS[\\s\\S]+ROLLBACK;/m, newEnd);

let assertions = '    DECLARE\\n' +
'        c_staging int;\\n' +
'        v_status text;\\n' +
'        v_batches int;\\n' +
'        v_staged int;\\n' +
'    BEGIN\\n' +
'        SELECT status INTO v_status FROM data_imports.geography_releases WHERE id = v_release_id;\\n' +
'        IF v_status != \\'STAGED\\' THEN RAISE EXCEPTION \\'Release not STAGED: %\\', v_status; END IF;\\n' +
'        \\n' +
'        SELECT count(*) INTO v_batches FROM data_imports.batches WHERE release_id = v_release_id;\\n' +
'        SELECT count(*) INTO v_staged FROM data_imports.batches WHERE release_id = v_release_id AND status = \\'STAGED\\';\\n' +
'        IF v_batches != 144 THEN RAISE EXCEPTION \\'Batches != 144\\'; END IF;\\n' +
'        IF v_staged != 143 THEN RAISE EXCEPTION \\'Staged Batches != 143\\'; END IF;\\n' +
'        \\n' +
'        SELECT count(*) INTO c_staging FROM staging.geography_imports WHERE release_id = v_release_id;\\n' +
'        IF c_staging != 15250 THEN RAISE EXCEPTION \\'Staging rows != 15250\\'; END IF;\\n' +
'    END;\\n' +
'\\n' +
'    SELECT count(*) INTO c_state FROM catalog.geography_units WHERE geography_level_id = state_lvl;\\n' +
'    SELECT count(*) INTO c_dist FROM catalog.geography_units WHERE geography_level_id = district_lvl;\\n' +
'    SELECT count(*) INTO c_subdist FROM catalog.geography_units WHERE geography_level_id = subdistrict_lvl;\\n' +
'    SELECT count(*) INTO c_block FROM catalog.development_blocks;\\n' +
'    SELECT count(*) INTO c_rel FROM catalog.block_districts;\\n' +
'    IF c_state != 36 OR c_dist != 0 OR c_subdist != 0 OR c_block != 0 OR c_rel != 0 THEN\\n' +
'        RAISE EXCEPTION \\'Canonical baseline not clean! %, %, %, %, %\\', c_state, c_dist, c_subdist, c_block, c_rel;\\n' +
'    END IF;\\n';

rehearsal = rehearsal.replace(/SELECT id INTO subdistrict_lvl FROM catalog.geography_levels WHERE level_key = 'SUB_DISTRICT';/g, 
    'SELECT id INTO subdistrict_lvl FROM catalog.geography_levels WHERE level_key = \\'SUB_DISTRICT\\';\\n\\n' + assertions);

fs.writeFileSync('D:/NAMISH_GLOBAL_CONTROL/r16_cli_commit_20260901_203200/supabase/migrations/20260901000003_r16_promotion_commit.sql', rehearsal);
console.log('Adapter created.');
