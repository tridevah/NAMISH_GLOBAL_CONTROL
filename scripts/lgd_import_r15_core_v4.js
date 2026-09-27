const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const yauzl = require('yauzl');
const XLSX = require('xlsx');
const uuid = require('uuid');
const { Client } = require('pg');

const SRC = 'D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826';
const MANIFEST_PATH = path.join(SRC, 'sealed_manifest_r15.json');
const manifest = JSON.parse(fs.readFileSync(MANIFEST_PATH, 'utf8'));

const UUID_NAMESPACE = '6ba7b810-9dad-11d1-80b4-00c04fd430c8';

async function buildObservationKey(release_id, logical_batch_key, physical_source_sha256, internal_member, row_num, logical_ordinal, emitted_ordinal) {
    const tuple = JSON.stringify([
        "OBS_V3", release_id, logical_batch_key, physical_source_sha256, 
        internal_member, row_num, logical_ordinal, emitted_ordinal
    ]);
    return uuid.v5(tuple, UUID_NAMESPACE);
}

const client = new Client({
    user: 'postgres',
    host: 'localhost',
    database: 'postgres',
    port: 54522,
    password: 'postgres'
});

async function run() {
    await client.connect();
    
    const relRes = await client.query("SELECT id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R15'");
    const releaseId = relRes.rows[0].id;
    
    const importerHash = crypto.createHash('sha256').update(fs.readFileSync(__filename)).digest('hex');
    console.log('Importer Hash:', importerHash);
    
    let totalStaged = 0;
    
    for (const entry of manifest.entries) {
        const zipName = entry.path.split('!')[0];
        const fileName = entry.path.split('!')[1];
        
        let buf = await readZipFile(path.join(SRC, zipName), fileName);
        const physicalSourceSha256 = crypto.createHash('sha256').update(buf).digest('hex');
        
        let wb = XLSX.read(buf, {type: 'buffer'});
        let ws = wb.Sheets[wb.SheetNames[0]];
        let rawRows = XLSX.utils.sheet_to_json(ws, {header:1, defval:''});
        
        let headerIdx = rawRows.findIndex(r => r[0] && String(r[0]).toLowerCase().includes('s.no') || String(r[0]).toLowerCase().includes('s. no'));
        let header = rawRows[headerIdx].map(c=>String(c).toLowerCase().trim().replace(/\r?\n/g, ' '));
        
        for (const out of entry.logical_outputs) {
            const logicalKey = entry.path + '!!' + out.logical_entity + '!' + out.ordinal;
            const batchRes = await client.query("SELECT id FROM data_imports.batches WHERE release_id = $1 AND logical_batch_key = $2", [releaseId, logicalKey]);
            const batchId = batchRes.rows[0].id;
            
            await client.query("UPDATE data_imports.batches SET status = 'EXTRACTING', started_at = now() WHERE id = $1", [batchId]);
            
            let dataRows = [];
            if (out.logical_entity === 'STATE') {
                let titleRow = String(rawRows[1][0]);
                dataRows.push({ phys_row: 2, raw: { TITLE: titleRow } });
            } else {
                let codeIdx = header.findIndex(c => c === 'district code' || c === 'subdistrict code' || c === 'sub-district code' || c === 'block code');
                if(fileName.includes('districtofSpecific')) codeIdx = header.findIndex(c => c === 'district code');
                
                for (let i = headerIdx + 1; i < rawRows.length; i++) {
                    let r = rawRows[i];
                    if (r[codeIdx] && !isNaN(parseInt(r[codeIdx]))) {
                        let obj = {};
                        header.forEach((h, idx) => obj[h] = r[idx]);
                        dataRows.push({ phys_row: i + 1, raw: obj });
                    }
                }
            }
            
            let inserted = 0;
            for (let i = 0; i < dataRows.length; i++) {
                const r = dataRows[i];
                const rawPayloadStr = JSON.stringify(r.raw);
                const rawPayloadSha256 = crypto.createHash('sha256').update(rawPayloadStr).digest('hex');
                const obsKey = await buildObservationKey(releaseId, logicalKey, physicalSourceSha256, fileName, r.phys_row, out.ordinal, i);
                
                const q = "INSERT INTO staging.geography_imports (release_id, batch_id, source_observation_key, entity_type, physical_source_sha256, internal_member_or_sheet, physical_row_number, logical_output_ordinal, emitted_record_ordinal, raw_data, raw_payload_sha256, observation_identity_version) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)";
                await client.query(q, [releaseId, batchId, obsKey, out.logical_entity, physicalSourceSha256, fileName, r.phys_row, out.ordinal, i, r.raw, rawPayloadSha256, 'OBS_V3']);
                inserted++;
            }
            
            await client.query("UPDATE data_imports.batches SET status = 'STAGED', completed_at = now(), staged_rows = $1, successful_records = $1, total_records = $1 WHERE id = $2", [inserted, batchId]);
            totalStaged += inserted;
        }
    }
    
    console.log("Total Staged Rows:", totalStaged);
    await client.query("UPDATE data_imports.releases SET status = 'STAGED', completed_at = now() WHERE id = $1", [releaseId]);
    await client.end();
}

function readZipFile(zipPath, fileName) {
    return new Promise((resolve, reject) => {
        yauzl.open(zipPath, {lazyEntries: true}, (err, zf) => {
            if (err) return reject(err);
            zf.readEntry();
            zf.on('entry', (e) => {
                if (e.fileName === fileName || e.fileName.includes(fileName)) {
                    zf.openReadStream(e, (err, stream) => {
                        let buffers = [];
                        stream.on('data', d => buffers.push(d));
                        stream.on('end', () => resolve(Buffer.concat(buffers)));
                    });
                } else {
                    zf.readEntry();
                }
            });
            zf.on('end', () => reject(new Error('File not found in zip: ' + fileName)));
        });
    });
}

run().catch(console.error);
