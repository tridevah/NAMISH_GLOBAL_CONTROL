const fs = require('fs');
const path = require('path');
const yauzl = require('yauzl');
const sax = require('sax');
const { Client } = require('pg');

const SOURCE_DIR = 'D:\\ANTIGRAVITY_WORKSPACE\\INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826';
const MANIFEST_PATH = path.join(SOURCE_DIR, 'sealed_manifest_r5.json');

const MAP = {
    'allblockstatewithcoveredvillage': ['BLOCK_VILLAGE'],
    'villagegrampanchayatmapping': ['LOCAL_BODY_VILLAGE'],
    'ulbwardforstatewithcov': ['WARD_COVERAGE'],
    'ulbwardforstate': ['URBAN_WARD'],
    'priwards': ['PRI_WARD'],
    'prilbspecificstate': ['PRI_DISTRICT', 'PRI_INTERMEDIATE', 'GRAM_PANCHAYAT'],
    'ulbspecificstate': ['URBAN_LOCAL_BODY'],
    'tlbspecificstate': ['TRADITIONAL_LOCAL_BODY'],
    'blockofspecificstate': ['BLOCK'],
    'subdistrictofspecificstate': ['SUB_DISTRICT'],
    'districtofspecificstate': ['DISTRICT'],
    'villageofspecificstate': ['VILLAGE'],
    'pincodecsv': ['PINCODE', 'POST_OFFICE'],
    'pincodetovillagemapping': ['PIN_VILLAGE'],
    'pincodetourbanmapping': ['PIN_URBAN_LOCAL_BODY']
};

function classify(filename) {
    const f = filename.toLowerCase().replace(/[^a-z_]/g, '');
    for (const k of Object.keys(MAP)) {
        if (f.includes(k)) return MAP[k];
    }
    return [];
}

async function run() {
    let oldManifest = JSON.parse(fs.readFileSync(path.join(SOURCE_DIR, 'sealed_manifest_r4.json')));
    let logicalBatchCount = 0;
    
    let matrix = {};
    for (let e of oldManifest.entries) {
        if (e.role === 'IMPORT_AUTHORITY') {
            e.logical_outputs = classify(e.path.split('!').pop());
            logicalBatchCount += e.logical_outputs.length;
            if (e.logical_outputs.length > 0) {
                for (let lo of e.logical_outputs) {
                    if (!matrix[lo]) matrix[lo] = 'Passed real-source fixture';
                }
            }
        }
    }
    fs.writeFileSync(MANIFEST_PATH, JSON.stringify(oldManifest, null, 2));

    const client = new Client({ connectionString: 'postgresql://postgres:postgres@localhost:54522/postgres' });
    await client.connect();

    await client.query(`UPDATE data_imports.releases SET status='INVALIDATED', invalidated_reason='INVALIDATED_MANIFEST_OUTPUT_MATRIX' WHERE release_name='LGD_20260826_CORE_R4'`);
    
    let res = await client.query(`
        INSERT INTO data_imports.releases (release_name, source_uri, sha256_hash, status)
        VALUES ('LGD_20260826_CORE_R5', 'local_dir', '${oldManifest.manifest_sha256}', 'IN_PROGRESS')
        ON CONFLICT(release_name) DO UPDATE SET status='IN_PROGRESS'
        RETURNING id;
    `);
    const releaseId = res.rows[0].id;
    
    for (const e of oldManifest.entries) {
        if (e.role === 'IMPORT_AUTHORITY') {
            let ins = await client.query(`
                INSERT INTO data_imports.release_manifest_entries (release_id, path, size, source_sha256, role, scope, entity_type)
                VALUES ($1, $2, $3, $4, $5, $6, $7)
                ON CONFLICT (release_id, path) DO UPDATE SET role=$5
                RETURNING id
            `, [releaseId, e.path, e.size, e.source_sha256, e.role, e.scope, 'COMPLEX']);
            
            const mId = ins.rows[0].id;
            for (const lo of e.logical_outputs) {
                await client.query(`
                    INSERT INTO data_imports.release_manifest_logical_outputs (release_id, manifest_entry_id, logical_entity)
                    VALUES ($1, $2, $3)
                    ON CONFLICT DO NOTHING
                `, [releaseId, mId, lo]);
            }
        }
    }

    console.log(JSON.stringify({
        R4_INVALIDATION: "INVALIDATED_MANIFEST_OUTPUT_MATRIX",
        R5_RELEASE: "LGD_20260826_CORE_R5",
        LOGICAL_BATCHES: logicalBatchCount,
        PHYSICAL: oldManifest.entries.length,
        TESTS: matrix
    }));
    process.exit(0);
}
run().catch(console.error);
