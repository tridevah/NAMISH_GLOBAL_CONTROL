with open('D:/NAMISH_GLOBAL_CONTROL/r16_cli_dryrun_20260901_183500/supabase/migrations/20260901000003_r16_promotion_rehearsal.sql', 'r') as f:
    original = f.read()

# Replace the terminal exception and ROLLBACK
old_terminal = "RAISE EXCEPTION 'SUCCESS|%|%|%|%', COALESCE(i_dist,0), COALESCE(i_subdist,0), COALESCE(i_block,0), COALESCE(i_rel,0);"
new_terminal = """INSERT INTO data_imports.release_execution_artifacts 
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

# Replace rollback with commit
import re
adapted = re.sub(r'\nROLLBACK;\s*$', '\nCOMMIT;\n', adapted)

# Replace advisory lock key
adapted = adapted.replace("hashtext('LGD_CORE_R16_REHEARSAL')", "hashtext('LGD_CORE_PROMOTION')")

# The BEGIN ISOLATION LEVEL SERIALIZABLE + COMMIT wrapper stays - it's the outer transaction
# The runner treats the entire file as a migration, running each ; statement in sequence
# BUT the Supabase runner wraps each migration file in its own transaction.
# So BEGIN and COMMIT inside the file conflict with the runner's own transaction wrapping.
# Solution: Comment them out and rely on the runner's transaction + SET TRANSACTION for isolation.

adapted = adapted.replace('BEGIN ISOLATION LEVEL SERIALIZABLE;\n', 
                           'SET TRANSACTION ISOLATION LEVEL SERIALIZABLE; -- promoted from BEGIN\n')
adapted = re.sub(r'\nCOMMIT;\s*$', '\n-- COMMIT handled by migration runner\n', adapted)

# Now add the pre-commit gate assertions INSIDE the DO block (before DML)
# Insert after the subdistrict_lvl SELECT
target = "SELECT id INTO subdistrict_lvl FROM catalog.geography_levels WHERE level_key = 'SUB_DISTRICT';"

pre_gate = """
    -- Pre-commit gate assertions (inside DO block, after level lookups)
    DECLARE
        _c_staging int;
        _v_status text;
        _v_batches int;
        _v_staged int;
    BEGIN
        SELECT status INTO _v_status FROM data_imports.releases WHERE id = v_release_id;
        IF _v_status != 'STAGED' THEN RAISE EXCEPTION 'Gate: Release not STAGED: %', _v_status; END IF;
        SELECT count(*) INTO _v_batches FROM data_imports.batches WHERE release_id = v_release_id;
        IF _v_batches != 143 THEN RAISE EXCEPTION 'Gate: Batches != 143, got: %', _v_batches; END IF;
        SELECT count(*) INTO _v_staged FROM data_imports.batches WHERE release_id = v_release_id AND status = 'STAGED';
        IF _v_staged != 143 THEN RAISE EXCEPTION 'Gate: Staged batches != 143, got: %', _v_staged; END IF;
        SELECT count(*) INTO _c_staging FROM staging.geography_imports WHERE release_id = v_release_id;
        IF _c_staging != 15250 THEN RAISE EXCEPTION 'Gate: Staging rows != 15250, got: %', _c_staging; END IF;
    END;
"""

adapted = adapted.replace(target, target + '\n' + pre_gate)

# Add canonical baseline check (after the pre-gate and before DML)
canon_check = """
    -- Canonical baseline must be clean before DML
    SELECT count(*) INTO c_state FROM catalog.geography_units WHERE geography_level_id = state_lvl;
    SELECT count(*) INTO c_dist FROM catalog.geography_units WHERE geography_level_id = district_lvl;
    SELECT count(*) INTO c_subdist FROM catalog.geography_units WHERE geography_level_id = subdistrict_lvl;
    SELECT count(*) INTO c_block FROM catalog.development_blocks;
    SELECT count(*) INTO c_rel FROM catalog.block_districts;
    IF c_state != 36 OR c_dist != 0 OR c_subdist != 0 OR c_block != 0 OR c_rel != 0 THEN
        RAISE EXCEPTION 'Canonical baseline not clean! states=% dist=% subdist=% blocks=% rels=%',
            c_state, c_dist, c_subdist, c_block, c_rel;
    END IF;

"""

# Insert canon check after the pre_gate block (before SELECT row_to_json)
norm_check_target = '    SELECT row_to_json(n) INTO err_rec FROM _r16_norm n WHERE n.entity_code IS NULL'
adapted = adapted.replace(norm_check_target, canon_check + '    ' + norm_check_target.strip())

with open('D:/NAMISH_GLOBAL_CONTROL/r16_cli_commit_20260901_203200/supabase/migrations/20260901000004_r16_promotion_commit.sql', 'w') as f:
    f.write(adapted)

lines = adapted.split('\n')
print('Total lines:', len(lines))
print('Last 15:', lines[-15:])
