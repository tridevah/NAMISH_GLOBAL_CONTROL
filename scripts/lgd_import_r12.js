const fs = require('fs');
const path = require('path');
const { Client } = require('pg');

const DB_URL = 'postgresql://postgres:postgres@localhost:54522/postgres';
const MANIFEST = 'D:\\ANTIGRAVITY_WORKSPACE\\INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826\\sealed_manifest_r6.json';

async function run() {
    const client = new Client({ connectionString: DB_URL });
    await client.connect();

    const lock = await client.query('SELECT pg_try_advisory_lock(202608267)');
    if (!lock.rows[0].pg_try_advisory_lock) { console.log('Advisory lock held. Exiting.'); process.exit(1); }

    const manifestStr = fs.readFileSync(MANIFEST, 'utf8');
    const manifest = JSON.parse(manifestStr);
    const mHash = require('crypto').createHash('sha256').update(manifestStr).digest('hex');
    // Register R12
    let res = await client.query(`SELECT id FROM data_imports.releases WHERE release_name='LGD_20260826_CORE_R12'`);
    let releaseId;
    if (res.rows.length) {
        releaseId = res.rows[0].id;
    } else {
        res = await client.query(`INSERT INTO data_imports.releases (release_name, status, manifest_hash, source_uri, sha256_hash)
            VALUES ('LGD_20260826_CORE_R12', 'REGISTERED', $1, 'D:\\ANTIGRAVITY_WORKSPACE\\INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826\\sealed_manifest_r6.json', $1) RETURNING id`, [mHash]);
        releaseId = res.rows[0].id;
    }
    
    console.log(`R12 Release ID: ${releaseId}`);

    for (const entry of manifest.entries) {
        let mR = await client.query(`INSERT INTO data_imports.release_manifest_entries (release_id, path, size, source_sha256, role, scope, entity_type)
            VALUES ($1,$2,$3,$4,$5,$6,$7) ON CONFLICT(release_id, path) DO UPDATE SET role=$5 RETURNING id`,
            [releaseId, entry.path, entry.size, entry.source_sha256, entry.role, entry.scope, 'UNKNOWN']);
        let mId = mR.rows[0].id;

        if (entry.role === 'IMPORT_AUTHORITY' && entry.logical_outputs) {
            for (let j=0; j<entry.logical_outputs.length; j++) {
                const lo = entry.logical_outputs[j];
                const parts = entry.path.split('!');
                const normRelPath = (parts[0]||'').replace(/\\/g, '/');
                const internalSheet = parts[1] || '';
                const logicalBatchKey = `${normRelPath}!${internalSheet}!${lo}!${j}`;

                const loR = await client.query(`INSERT INTO data_imports.release_manifest_logical_outputs 
                    (release_id, manifest_entry_id, logical_entity) VALUES ($1,$2,$3) ON CONFLICT DO NOTHING RETURNING id`, [releaseId, mId, lo]);
                let loId = loR.rows.length ? loR.rows[0].id : null;
                if (!loId) {
                    const sel = await client.query('SELECT id FROM data_imports.release_manifest_logical_outputs WHERE release_id=$1 AND manifest_entry_id=$2 AND logical_entity=$3', [releaseId, mId, lo]);
                    if (sel.rows.length) loId = sel.rows[0].id;
                }

                await client.query(`
                INSERT INTO data_imports.batches (release_id, entity_type, status, manifest_logical_output_id, logical_batch_key)
                VALUES ($1, $2, 'PENDING', $3, $4)
                ON CONFLICT(release_id, logical_batch_key) WHERE logical_batch_key IS NOT NULL DO UPDATE SET status='PENDING'
                `, [releaseId, lo, loId, logicalBatchKey]);
            }
        }
    }

    const bCount = await client.query("SELECT count(*) FROM data_imports.batches WHERE release_id=$1", [releaseId]);
    console.log(`R12 batch count: ${bCount.rows[0].count}`);

    await client.query('SELECT pg_advisory_unlock(202608267)');
    await client.end();
}

run().catch(err => { console.log('FATAL:', err.message); process.exit(1); });
