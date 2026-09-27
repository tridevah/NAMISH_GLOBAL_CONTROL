with open('D:/NAMISH_GLOBAL_CONTROL/r16_cli_dryrun_20260901_183500/supabase/migrations/20260901000003_r16_promotion_rehearsal.sql', 'r') as f:
    original = f.read()

# The original rehearsal has the structure:
# BEGIN ISOLATION LEVEL SERIALIZABLE;
# SELECT pg_advisory_xact_lock(...);
# SET search_path TO...;
# SET CONSTRAINTS ALL IMMEDIATE;
# CREATE TEMPORARY TABLE _r16_norm ...;
# INSERT INTO _r16_norm ... VALUES ... (batches);
# DO  DECLARE ... BEGIN ... RAISE EXCEPTION 'SUCCESS...'; END; ;
# ROLLBACK;

# For the commit adapter, we need ONE file the runner can handle.
# The Supabase runner runs each ; separated statement. 
# The problem: CREATE TEMP TABLE and INSERT statements before the DO block are separate statements,
# and the temp table is NOT visible in the DO block's transaction scope IF the runner uses autocommit.

# SOLUTION: Wrap EVERYTHING from CREATE TEMP TABLE to the DO block END in a single DO  ;
# The SET TRANSACTION, pg_advisory_xact_lock, search_path can stay as separate statements.

# 1. Split the original into preamble (before CREATE TEMP) and the rest
create_temp_pos = original.find('\nCREATE TEMPORARY TABLE _r16_norm')
preamble = original[:create_temp_pos]
body = original[create_temp_pos:]

# 2. Find the end of the DO block (the ROLLBACK; at end)
rollback_pos = body.rfind('\nROLLBACK;')
do_body = body[:rollback_pos]  # From CREATE TEMP to end of DO block

# 3. The DO block is already there. We need to merge it so that CREATE TEMP and INSERTs
# happen in the same scope as the DO block logic.
# Approach: Remove the outer DO  ... ; wrapper from the original DO block
# and incorporate its DECLARE...END content into a new single DO block
# that starts with CREATE TEMP TABLE and the INSERTs.

# Find where the original DO  starts  
do_block_pos = do_body.rfind('\nDO \n')
if do_block_pos == -1:
    do_block_pos = do_body.rfind('\nDO \r\n')

pre_do = do_body[:do_block_pos]  # CREATE TEMP + all INSERTs
do_block_content = do_body[do_block_pos:]  # \nDO \nDECLARE...END;\n;

# Extract the DECLARE...END from the DO block
declare_pos = do_block_content.find('DECLARE')
end_dollar = do_block_content.rfind(';')
inner_block = do_block_content[declare_pos:end_dollar]  # DECLARE...END;\n

# Build new commit SQL
new_sql = ''

# Keep preamble - remove BEGIN ISOLATION LEVEL SERIALIZABLE, replace with SET TRANSACTION
preamble_clean = preamble.replace('BEGIN ISOLATION LEVEL SERIALIZABLE;\n', 
                                   'SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;\n')
preamble_clean = preamble_clean.replace("hashtext('LGD_CORE_R16_REHEARSAL')", 
                                         "hashtext('LGD_CORE_PROMOTION')")
new_sql += preamble_clean.strip() + '\n\n'

# Now one big DO block
new_sql += 'DO \n'
new_sql += inner_block  # DECLARE block from original DO

# Before the original BEGIN in the inner block, we need to insert CREATE TEMP + INSERTs
# Find BEGIN in inner_block
begin_pos = inner_block.find('\nBEGIN\n')
if begin_pos == -1:
    begin_pos = inner_block.find('\nBEGIN\r\n')

# Insert the pre_do content (CREATE TEMP TABLE + INSERTs) right after BEGIN
new_inner = (inner_block[:begin_pos + 6] +  # ... up to and including BEGIN\n
             pre_do.strip() + '\n\n' +         # CREATE TEMP + INSERTs
             inner_block[begin_pos + 6:])      # rest of DO block

# Replace the RAISE EXCEPTION SUCCESS with evidence INSERT + no terminal exception
new_inner = new_inner.replace(
    \"RAISE EXCEPTION 'SUCCESS|%|%|%|%', COALESCE(i_dist,0), COALESCE(i_subdist,0), COALESCE(i_block,0), COALESCE(i_rel,0);\",
    '''INSERT INTO data_imports.release_execution_artifacts 
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
            'adapter_sha256', 'CC61A483644F966E420B2753447311495EB2E12F13B36A4551D06D18DEFC0F17'
        )
    );
    RAISE NOTICE 'R16 PROMOTION COMMITTED: dist=% subdist=% blocks=% rels=%', COALESCE(i_dist,0), COALESCE(i_subdist,0), COALESCE(i_block,0), COALESCE(i_rel,0);'''
)

new_sql = new_sql[:new_sql.find('DO \n') + 6]  # Keep up to and including DO \n
new_sql += new_inner
new_sql += '\n;\n'

# Add the pre-commit assertions inside the DO block before DML
# (add after BEGIN and after the CREATE TEMP+INSERT section, before the unmatched_count check)
pre_dml_assert = '''
    -- Pre-commit gate assertions
    DECLARE
        _c_staging int;
        _v_status text;
        _v_batches int;
        _v_staged int;
    BEGIN
        SELECT status INTO _v_status FROM data_imports.releases WHERE id = v_release_id;
        IF _v_status != 'STAGED' THEN RAISE EXCEPTION 'Release not STAGED: %', _v_status; END IF;
        
        SELECT count(*) INTO _v_batches FROM data_imports.batches WHERE release_id = v_release_id;
        IF _v_batches != 143 THEN RAISE EXCEPTION 'Batches != 143, got: %', _v_batches; END IF;
        
        SELECT count(*) INTO _v_staged FROM data_imports.batches WHERE release_id = v_release_id AND status = 'STAGED';
        IF _v_staged != 143 THEN RAISE EXCEPTION 'Staged batches != 143, got: %', _v_staged; END IF;
        
        SELECT count(*) INTO _c_staging FROM staging.geography_imports WHERE release_id = v_release_id;
        IF _c_staging != 15250 THEN RAISE EXCEPTION 'Staging rows != 15250, got: %', _c_staging; END IF;
    END;

    -- Canonical baseline check (should be clean: 36 states, 0 others)
    SELECT count(*) INTO c_state FROM catalog.geography_units WHERE geography_level_id = state_lvl;
    SELECT count(*) INTO c_dist FROM catalog.geography_units WHERE geography_level_id = district_lvl;
    SELECT count(*) INTO c_subdist FROM catalog.geography_units WHERE geography_level_id = subdistrict_lvl;
    SELECT count(*) INTO c_block FROM catalog.development_blocks;
    SELECT count(*) INTO c_rel FROM catalog.block_districts;
    IF c_state != 36 OR c_dist != 0 OR c_subdist != 0 OR c_block != 0 OR c_rel != 0 THEN
        RAISE EXCEPTION 'Canonical baseline not clean! %, %, %, %, %', c_state, c_dist, c_subdist, c_block, c_rel;
    END IF;

'''

# Insert pre_dml_assert after the SELECT subdistrict_lvl line
target = \"SELECT id INTO subdistrict_lvl FROM catalog.geography_levels WHERE level_key = 'SUB_DISTRICT';\"
new_sql = new_sql.replace(target, target + '\n' + pre_dml_assert)

with open('D:/NAMISH_GLOBAL_CONTROL/r16_cli_commit_20260901_203200/supabase/migrations/20260901000004_r16_promotion_commit.sql', 'w') as f:
    f.write(new_sql)

lines = new_sql.split('\n')
print('Total lines:', len(lines))
print('First 10:', lines[:10])
print('Last 10:', lines[-10:])
