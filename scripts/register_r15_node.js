const fs = require('fs');
const { Client } = require('pg');
const m = JSON.parse(fs.readFileSync('D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826/sealed_manifest_r15.json', 'utf8'));

async function run() {
    const client = new Client({
        user: 'postgres',
        host: 'localhost',
        database: 'postgres',
        port: 54322,
        password: 'postgres'
    });
    await client.connect();
    
    try {
        await client.query('BEGIN');
        
        // R15 uses a fake manifest hash here just to get the release ID
        const release_name = 'LGD_20260826_CORE_R15';
        const sha256_hash = '0000000000000000000000000000000000000000000000000000000000000000';
        
        const res = await client.query("INSERT INTO data_imports.releases (release_name, source_uri, sha256_hash, status) VALUES (, , , 'EXTRACTING') RETURNING id", [release_name, 'LOCAL_WORKSPACE', sha256_hash]);
        const r15_id = res.rows[0].id;
        
        let batchCount = 0;
        
        for (const entry of m.entries) {
            const entryRes = await client.query(
                "INSERT INTO data_imports.release_manifest_entries (release_id, path, size, source_sha256, role, scope, entity_type) VALUES (, , , , , , ) RETURNING id",
                [r15_id, entry.path, 0, '00', 'PHYSICAL', 'STATE', 'MULTIPLE']
            );
            const entryId = entryRes.rows[0].id;
            
            for (let i = 0; i < entry.logical_outputs.length; i++) {
                const lo = entry.logical_outputs[i];
                const loRes = await client.query(
                    "INSERT INTO data_imports.release_manifest_logical_outputs (manifest_entry_id, array_index, target_entity_type) VALUES (, , ) RETURNING id",
                    [entryId, lo.ordinal, lo.logical_entity]
                );
                
                const logicalKey = entry.path + '!!' + lo.logical_entity + '!' + lo.ordinal;
                await client.query(
                    "INSERT INTO data_imports.batches (release_id, manifest_logical_output_id, logical_batch_key, entity_type, status, total_records, successful_records, failed_records) VALUES (, , , , 'PENDING', 0, 0, 0)",
                    [r15_id, loRes.rows[0].id, logicalKey, lo.logical_entity]
                );
                batchCount++;
            }
        }
        
        if (batchCount !== 144) throw new Error('Expected 144 batches, got ' + batchCount);
        
        await client.query('COMMIT');
        console.log('R15 registered successfully. Release ID:', r15_id);
    } catch (e) {
        await client.query('ROLLBACK');
        console.error('Registration failed:', e);
    } finally {
        await client.end();
    }
}
run();
