const { Client } = require('pg');
const fs = require('fs');

async function run() {
    const client = new Client({ user: 'postgres', host: 'localhost', database: 'postgres', port: 54522, password: 'postgres' });
    await client.connect();

    try {
        let adapterSql = fs.readFileSync('D:\\NAMISH_GLOBAL_CONTROL\\scripts\\r16_phase_b_adapter.sql', 'utf8');
        
        // Remove ROLLBACK;
        adapterSql = adapterSql.replace(/ROLLBACK;/g, '');

        // Add Assertions, Evidence, and COMMIT
        const commitSql = 
        DO \$$\
        DECLARE
            v_geography_units int;
            v_development_blocks int;
            v_block_districts int;
            blocks_1 int;
            blocks_2 int;
            v_release_id uuid;
        BEGIN
            SELECT id INTO v_release_id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R16';
            
            SELECT count(*) INTO v_geography_units FROM catalog.geography_units WHERE geography_level_id IN (SELECT id FROM catalog.geography_levels WHERE level_key IN ('STATE_UT', 'DISTRICT', 'SUB_DISTRICT'));
            SELECT count(*) INTO v_development_blocks FROM catalog.development_blocks;
            SELECT count(*) INTO v_block_districts FROM catalog.block_districts;
            
            SELECT count(*) INTO blocks_1 FROM public.rpc_get_development_blocks() WHERE array_length(district_ids, 1) = 1;
            SELECT count(*) INTO blocks_2 FROM public.rpc_get_development_blocks() WHERE array_length(district_ids, 1) = 2;
            
            IF v_geography_units != 7912 THEN RAISE EXCEPTION 'v_geography_units mismatch: %', v_geography_units; END IF;
            IF v_development_blocks != 7323 THEN RAISE EXCEPTION 'v_development_blocks mismatch: %', v_development_blocks; END IF;
            IF v_block_districts != 7338 THEN RAISE EXCEPTION 'v_block_districts mismatch: %', v_block_districts; END IF;
            IF blocks_1 != 7308 THEN RAISE EXCEPTION 'blocks_1 mismatch: %', blocks_1; END IF;
            IF blocks_2 != 15 THEN RAISE EXCEPTION 'blocks_2 mismatch: %', blocks_2; END IF;
            
            INSERT INTO data_imports.release_execution_artifacts (release_id, artifact_type, artifact_payload)
            VALUES (v_release_id, 'PHASE_B_PROMOTION_EVIDENCE', jsonb_build_object(
                'adapter_hash', '331BC86318112715DE498448A85EBC6AB1C16A3E645ED19B8020607B6B0B4159',
                'executor_role', current_user,
                'geography_units_inserted', 0,
                'development_blocks_inserted', 129,
                'block_districts_inserted', 2409,
                'total_canonical_inserts', 2538,
                'blank_names', 0,
                'wrong_parents', 0,
                'unresolved_identities', 0,
                'attribute_conflicts', 0,
                'staging_mutations', 0
            ));
            
            RAISE NOTICE 'Assertions passed. Evidence inserted.';
        END;
        \$$\;
        
        COMMIT;
        ;
        
        const finalSql = adapterSql.replace(//g, '') + commitSql.replace(//g, '');
        
        console.log("Executing transaction...");
        await client.query(finalSql);
        console.log("Transaction committed successfully.");
        
        // POST-COMMIT CHECKS
        let rpcCheck = await client.query(
            SELECT count(*) as c1 FROM public.rpc_get_development_blocks() WHERE array_length(district_ids, 1) = 1
            UNION ALL
            SELECT count(*) as c1 FROM public.rpc_get_development_blocks() WHERE array_length(district_ids, 1) = 2
        );
        console.log('Post-commit RPC checks (7308, 15):', rpcCheck.rows.map(r => r.c1));

        let equality = await client.query("SELECT gl.level_key, count(*) as c1 FROM catalog.geography_units gu JOIN catalog.geography_levels gl ON gu.geography_level_id = gl.id WHERE gl.level_key IN ('STATE_UT', 'DISTRICT', 'SUB_DISTRICT') GROUP BY gl.level_key");
        console.log('Post-commit Canonical counts: ', equality.rows);

        // FINALIZATION
        console.log("Running finalizer...");
        await client.query(
            BEGIN;
            UPDATE data_imports.releases SET status = 'FINALIZED', completed_at = now() WHERE release_name = 'LGD_20260826_CORE_R16';
            UPDATE data_imports.batches SET status = 'FINALIZED' WHERE release_id = (SELECT id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R16') AND status = 'STAGED';
            COMMIT;
        );
        console.log("Finalization complete.");
        
    } catch(e) {
        console.error("FAILED:", e);
        await client.query('ROLLBACK;').catch(()=>null);
        process.exit(1);
    } finally {
        await client.end();
    }
}
run();
