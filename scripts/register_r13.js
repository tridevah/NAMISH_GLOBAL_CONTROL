const fs = require('fs');
const { Client } = require('pg');
const m = JSON.parse(fs.readFileSync('D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826/sealed_manifest_r13.json', 'utf8'));

async function run() {
    const client = new Client({
        user: 'postgres',
        host: 'localhost',
        database: 'postgres',
        port: 54322,
        password: 'postgres' // default for local supabase
    });
    await client.connect();
    
    try {
        await client.query('BEGIN');
        
        const r13_id = (await client.query("INSERT INTO data_imports.releases (release_name, status, total_batches) VALUES ('LGD_20260826_CORE_R13', 'EXTRACTING', 508) RETURNING id")).rows[0].id;
        
        let batchCount = 0;
        
        for (const entry of m.entries) {
            const entryId = (await client.query(
                "INSERT INTO data_imports.release_manifest_entries (release_id, path, size, source_sha256, role, scope, entity_type) VALUES (, , , , , , ) RETURNING id",
                [r13_id, entry.path, entry.size, entry.source_sha256, entry.role, entry.scope, 'UNKNOWN']
            )).rows[0].id;
            
            for (let i = 0; i < entry.logical_outputs.length; i++) {
                const lo = entry.logical_outputs[i];
                await client.query(
                    "INSERT INTO data_imports.release_manifest_logical_outputs (manifest_entry_id, array_index, target_entity_type) VALUES (, , )",
                    [entryId, i, lo]
                );
                
                const logicalKey = entry.path + '!!' + lo + '!' + i;
                await client.query(
                    "INSERT INTO data_imports.batches (release_id, logical_batch_key, entity_type, status) VALUES (, , , 'PENDING')",
                    [r13_id, logicalKey, lo]
                );
                batchCount++;
            }
        }
        
        if (batchCount !== 508) throw new Error('Expected 508 batches, got ' + batchCount);
        
        await client.query('COMMIT');
        console.log('R13 registered successfully. Release ID:', r13_id);
    } catch (e) {
        await client.query('ROLLBACK');
        console.error('Registration failed:', e);
    } finally {
        await client.end();
    }
}
run();
