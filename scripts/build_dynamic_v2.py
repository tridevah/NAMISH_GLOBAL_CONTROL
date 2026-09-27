import re

with open('D:/NAMISH_GLOBAL_CONTROL/r16_cli_dryrun_20260901_183500/supabase/migrations/20260901000003_r16_promotion_rehearsal.sql', 'r') as f:
    content = f.read()

# 1. Terminal exception -> PROMOTED status, evidence, NOTICE
old_terminal = "RAISE EXCEPTION 'SUCCESS|%|%|%|%', COALESCE(i_dist,0), COALESCE(i_subdist,0), COALESCE(i_block,0), COALESCE(i_rel,0);"
new_terminal = """
    -- Note: 000007 finalization will finalize batches. We just set PROMOTED here.
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

content = content.replace(old_terminal, new_terminal)
content = re.sub(r'\nROLLBACK;\s*$', '\n-- COMMIT handled by migration runner\n', content)
content = content.replace("hashtext('LGD_CORE_R16_REHEARSAL')", "hashtext('LGD_CORE_PROMOTION')")
content = content.replace('BEGIN ISOLATION LEVEL SERIALIZABLE;\n', 
                           'SET TRANSACTION ISOLATION LEVEL SERIALIZABLE; -- promoted from BEGIN\n')

# 2. Gate Assertions
gate = """
    DECLARE
        _c_staging int; _v_status text; _v_batches int; _v_staged int;
    BEGIN
        SELECT status INTO _v_status FROM data_imports.releases WHERE id = v_release_id;
        IF _v_status NOT IN ('STAGED', 'PROMOTED') THEN RAISE EXCEPTION 'Gate: Release not STAGED or PROMOTED: %', _v_status; END IF;
        SELECT count(*) INTO _v_batches FROM data_imports.batches WHERE release_id = v_release_id;
        IF _v_batches != 143 THEN RAISE EXCEPTION 'Gate: Batches != 143, got: %', _v_batches; END IF;
        SELECT count(*) INTO _c_staging FROM staging.geography_imports WHERE release_id = v_release_id;
        IF _c_staging != 15250 THEN RAISE EXCEPTION 'Gate: Staging rows != 15250, got: %', _c_staging; END IF;
    END;
"""
target_gate = "SELECT id INTO subdistrict_lvl FROM catalog.geography_levels WHERE level_key = 'SUB_DISTRICT';"
content = content.replace(target_gate, target_gate + '\n' + gate)

# 3. Dynamic logic
dml_start = '    SELECT row_to_json(n) INTO err_rec FROM _r16_norm n WHERE n.entity_code IS NULL'
dml_end = '    SELECT count(*) INTO c_state FROM catalog.geography_units WHERE geography_level_id = state_lvl;'

# Split the DO block into pre-DML, DML, and post-DML sections
start_idx = content.find(dml_start)
end_idx = content.rfind(dml_end)

pre_dml = content[:start_idx]
dml = content[start_idx:end_idx]
post_dml = content[end_idx:]

dynamic_wrapper_start = """
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

dynamic_wrapper_end = """
    ELSE
        RAISE EXCEPTION 'Canonical baseline not clean and not fully promoted! states=% dist=% subdist=% blocks=% rels=%',
            c_state, c_dist, c_subdist, c_block, c_rel;
    END IF;
"""

final_content = pre_dml + dynamic_wrapper_start + dml + dynamic_wrapper_end + post_dml

with open('D:/NAMISH_GLOBAL_CONTROL/r16_cli_repair_20260901_214500/supabase/migrations/20260901000004_r16_promotion_commit.sql', 'w') as f:
    f.write(final_content)

print("Proper dynamic 000004 reconstructed.")
