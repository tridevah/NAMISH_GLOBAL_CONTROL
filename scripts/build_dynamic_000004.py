with open('D:/NAMISH_GLOBAL_CONTROL/r16_cli_dryrun_20260901_183500/supabase/migrations/20260901000003_r16_promotion_rehearsal.sql', 'r') as f:
    original = f.read()

import re

# 1. Replace the terminal exception and ROLLBACK with PROMOTED notice and INSERT evidence
old_terminal = "RAISE EXCEPTION 'SUCCESS|%|%|%|%', COALESCE(i_dist,0), COALESCE(i_subdist,0), COALESCE(i_block,0), COALESCE(i_rel,0);"
new_terminal = """
    -- We only record the promotion evidence artifact here. 
    -- The release status PROMOTED will be set in the metadata finalization migration.
    -- (Actually, we can set PROMOTED here if we want to ensure atomicity of the DML with the status change).
    UPDATE data_imports.releases SET status = 'PROMOTED', completed_at = now() WHERE id = v_release_id AND status = 'STAGED';

    INSERT INTO data_imports.release_execution_artifacts 
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
            'rehearsal_sha256', 'CC61A483644F966E420B2753447311495EB2E12F13B36A4551D06D18DEFC0F17'
        )
    );
    RAISE NOTICE 'R16 PROMOTION COMMITTED: dist=% subdist=% blocks=% rels=%', 
        COALESCE(i_dist,0), COALESCE(i_subdist,0), COALESCE(i_block,0), COALESCE(i_rel,0);"""

adapted = original.replace(old_terminal, new_terminal)
adapted = re.sub(r'\nROLLBACK;\s*$', '\n-- COMMIT handled by migration runner\n', adapted)
adapted = adapted.replace("hashtext('LGD_CORE_R16_REHEARSAL')", "hashtext('LGD_CORE_PROMOTION')")
adapted = adapted.replace('BEGIN ISOLATION LEVEL SERIALIZABLE;\n', 
                           'SET TRANSACTION ISOLATION LEVEL SERIALIZABLE; -- promoted from BEGIN\n')

# 2. Add Pre-commit gate assertions BEFORE the dynamic branch
target_pre_gate = "SELECT id INTO subdistrict_lvl FROM catalog.geography_levels WHERE level_key = 'SUB_DISTRICT';"
pre_gate = """
    -- Pre-commit gate assertions (inside DO block, after level lookups)
    DECLARE
        _c_staging int;
        _v_status text;
        _v_batches int;
        _v_staged int;
    BEGIN
        SELECT status INTO _v_status FROM data_imports.releases WHERE id = v_release_id;
        IF _v_status NOT IN ('STAGED', 'PROMOTED') THEN RAISE EXCEPTION 'Gate: Release not STAGED or PROMOTED: %', _v_status; END IF;
        SELECT count(*) INTO _v_batches FROM data_imports.batches WHERE release_id = v_release_id;
        IF _v_batches != 143 THEN RAISE EXCEPTION 'Gate: Batches != 143, got: %', _v_batches; END IF;
        SELECT count(*) INTO _c_staging FROM staging.geography_imports WHERE release_id = v_release_id;
        IF _c_staging != 15250 THEN RAISE EXCEPTION 'Gate: Staging rows != 15250, got: %', _c_staging; END IF;
    END;
"""
adapted = adapted.replace(target_pre_gate, target_pre_gate + '\n' + pre_gate)

# 3. Dynamic branching for DML
canon_check = """
    -- Canonical baseline dynamic branch check
    SELECT count(*) INTO c_state FROM catalog.geography_units WHERE geography_level_id = state_lvl;
    SELECT count(*) INTO c_dist FROM catalog.geography_units WHERE geography_level_id = district_lvl;
    SELECT count(*) INTO c_subdist FROM catalog.geography_units WHERE geography_level_id = subdistrict_lvl;
    SELECT count(*) INTO c_block FROM catalog.development_blocks;
    SELECT count(*) INTO c_rel FROM catalog.block_districts;
    
    IF c_state = 36 AND c_dist = 784 AND c_subdist = 7092 AND c_block = 7323 AND c_rel = 7338 THEN
        RAISE NOTICE 'Canonical data already exists and matches expected promoted state. Skipping DML.';
        i_dist := 0; i_subdist := 0; i_block := 0; i_rel := 0;
    ELSIF c_state = 36 AND c_dist = 0 AND c_subdist = 0 AND c_block = 0 AND c_rel = 0 THEN
        RAISE NOTICE 'Canonical baseline clean. Proceeding with promotion DML.';
"""

norm_check_target = '    SELECT row_to_json(n) INTO err_rec FROM _r16_norm n WHERE n.entity_code IS NULL'
adapted = adapted.replace(norm_check_target, canon_check + '    ' + norm_check_target.strip())

# Close the IF block after the original DML logic, right before post-DML assertions
end_dml_target = '    SELECT count(*) INTO c_state FROM catalog.geography_units WHERE geography_level_id = state_lvl;'

end_dml_branch = """
    ELSE
        RAISE EXCEPTION 'Canonical baseline not clean and not fully promoted! states=% dist=% subdist=% blocks=% rels=%',
            c_state, c_dist, c_subdist, c_block, c_rel;
    END IF;
"""
adapted = adapted.replace(end_dml_target, end_dml_branch + '\n' + end_dml_target)

with open('D:/NAMISH_GLOBAL_CONTROL/r16_cli_repair_20260901_214500/supabase/migrations/20260901000004_r16_promotion_commit.sql', 'w') as f:
    f.write(adapted)

print("Dynamic branching 000004 created.")
