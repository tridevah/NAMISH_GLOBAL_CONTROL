const fs = require('fs');
const crypto = require('crypto');
const yauzl = require('yauzl');
const XLSX = require('xlsx');
const path = require('path');

const MANIFEST_PATH = 'D:/NAMISH_GLOBAL_CONTROL/r16_source/sealed_manifest_r16.json';
const BASE_DIR = 'D:/NAMISH_GLOBAL_CONTROL/r16_source';
const MANIFEST = JSON.parse(fs.readFileSync(MANIFEST_PATH));

const TARGET_ENTITIES = ['STATE', 'DISTRICT', 'SUB_DISTRICT', 'BLOCK'];

function deterministicUuid(seed) {
    const hash = crypto.createHash('sha1').update(seed).digest('hex');
    return `${hash.substr(0, 8)}-${hash.substr(8, 4)}-5${hash.substr(13, 3)}-8${hash.substr(17, 3)}-${hash.substr(20, 12)}`;
}

async function readZipFile(zipPath, entryPath) {
    return new Promise((resolve, reject) => {
        yauzl.open(zipPath, {lazyEntries: true}, (err, zf) => {
            if (err) return reject(err);
            zf.readEntry();
            let found = false;
            zf.on('entry', (e) => {
                if (e.fileName === entryPath || e.fileName.includes(entryPath.replace(/:/g, '-'))) {
                    found = true;
                    zf.openReadStream(e, (err, stream) => {
                        let buffers = [];
                        stream.on('data', d => buffers.push(d));
                        stream.on('end', () => resolve(Buffer.concat(buffers)));
                    });
                } else {
                    zf.readEntry();
                }
            });
            zf.on('end', () => {
                if (!found) reject(new Error('File not found in zip: ' + entryPath));
            });
        });
    });
}

async function parseSheet(buf, entityType, stateName) {
    let wb = XLSX.read(buf, {type: 'buffer'});
    let ws = wb.Sheets[wb.SheetNames[0]];
    let rawRows = XLSX.utils.sheet_to_json(ws, {header: 1, defval: ''});
    
    if (entityType === 'STATE') {
        let titleRow = String(rawRows[1] ? rawRows[1][0] : rawRows[0][0]);
        return [{ phys_row: 2, raw: { TITLE: titleRow } }];
    }

    let headerIdx = rawRows.findIndex(r => r[0] && (String(r[0]).toLowerCase().includes('s.no') || String(r[0]).toLowerCase().includes('s. no')));
    if (headerIdx === -1) throw new Error("Could not find header row");
    
    let header = rawRows[headerIdx].map(c => String(c).toLowerCase().trim().replace(/\r?\n/g, ' '));
    let dataRows = [];
    
    for (let i = headerIdx + 1; i < rawRows.length; i++) {
        let r = rawRows[i];
        if (!r[0] || String(r[0]).toLowerCase().includes('note')) continue; // skip empty or notes
        
        let obj = {};
        
        if (entityType === 'BLOCK') {
            if (stateName === 'ARUNACHAL PRADESH') {
                let codeIdx = header.findIndex(h => h === 'development block code');
                let enIdx = header.findIndex(h => h === 'development block name (in english)');
                
                if (codeIdx === -1 || enIdx === -1) throw new Error("Arunachal block headers missing");
                
                let code = r[codeIdx];
                if (!code || isNaN(code)) continue;
                
                let enName = String(r[enIdx]).trim();
                if (!enName) throw new Error("Arunachal Block English Name is blank at row " + i);
                
                header.forEach((h, idx) => {
                    if (h === 'development block name (in english)') obj['block name'] = String(r[idx]).trim();
                    else obj[h] = r[idx];
                });
            } else {
                let code = r[3];
                if (!code || isNaN(code)) continue; 
                
                let version = r[4];
                let enName = String(r[5]).trim();
                let locName = String(r[6]).trim();
                
                if (!enName) throw new Error(`State ${stateName} Block English Name is blank at row ${i} (Code: ${code})`);
                
                header.forEach((h, idx) => {
                    if (idx < 3 || idx > 6) obj[h] = r[idx];
                });
                
                obj['block code'] = code;
                obj['block version'] = version;
                obj['block name'] = enName;
                obj['block name local'] = locName;
            }
        } else {
            let codeIdx = -1;
            if (entityType === 'DISTRICT') codeIdx = header.findIndex(h => h === 'district code');
            else if (entityType === 'SUB_DISTRICT') codeIdx = header.findIndex(h => h === 'sub-district code' || h === 'subdistrict code');
            
            if (codeIdx === -1 || !r[codeIdx] || isNaN(r[codeIdx])) continue;

            header.forEach((h, idx) => obj[h] = r[idx]);
        }
        
        dataRows.push({ phys_row: i + 1, raw: obj });
    }
    return dataRows;
}

async function run() {
    let allData = [];
    let releaseId = '5fac63d7-0101-43c5-8867-bd75ff609861';
    
    for (let entry of MANIFEST.entries) {
        if (!entry.logical_outputs) continue;
        let validOutputs = entry.logical_outputs.filter(lo => TARGET_ENTITIES.includes(lo.logical_entity));
        if (validOutputs.length === 0) continue;
        
        let parts = entry.path.split('/');
        let stateName = parts[0];
        let zipName = parts[1].split('!')[0];
        let entryPath = parts[1].split('!')[1];
        
        let buf = await readZipFile(path.join(BASE_DIR, stateName, zipName), entryPath);
        let physicalSourceSha256 = crypto.createHash('sha256').update(buf).digest('hex');
        
        for (let lo of validOutputs) {
            let logicalKey = entry.path + '!!' + lo.logical_entity + '!' + lo.ordinal;
            let rows = await parseSheet(buf, lo.logical_entity, stateName);
            
            for (let r of rows) {
                let codeKey = null;
                if (lo.logical_entity === 'SUB_DISTRICT') codeKey = Object.keys(r.raw).find(k => k.includes('sub-district code') || k.includes('subdistrict code'));
                if (lo.logical_entity === 'BLOCK') codeKey = Object.keys(r.raw).find(k => k.includes('block code'));
                if (lo.logical_entity === 'DISTRICT') codeKey = Object.keys(r.raw).find(k => k === 'district code');
                
                let code = codeKey ? r.raw[codeKey] : null;
                if (lo.logical_entity === 'STATE') code = r.raw.TITLE;
                
                let distCodeKey = Object.keys(r.raw).find(k => k === 'district code');
                
                allData.push({
                    state: stateName,
                    entity: lo.logical_entity,
                    code: code,
                    districtCode: distCodeKey ? r.raw[distCodeKey] : null,
                    name: r.raw['block name'] || r.raw['development block name (in english)'],
                    payload: r.raw,
                    batchKey: logicalKey,
                    file: entryPath,
                    phys: r.phys_row,
                    ordinal: lo.ordinal,
                    physicalSourceSha256
                });
            }
        }
    }
    
    let states = allData.filter(d => d.entity === 'STATE').length;
    let districts = allData.filter(d => d.entity === 'DISTRICT').length;
    let subDistricts = allData.filter(d => d.entity === 'SUB_DISTRICT').length;
    let blocks = allData.filter(d => d.entity === 'BLOCK').length;
    
    if (states !== 36 || districts !== 784 || subDistricts !== 7092 || blocks !== 7338) {
        throw new Error(`Total counts assertion failed: ${states}, ${districts}, ${subDistricts}, ${blocks}`);
    }
    
    if (allData.length !== 15250) throw new Error("Total observations != 15250");
    
    let batches = Array.from(new Set(allData.map(d => d.batchKey)));
    let batchMap = {};
    
    let sql = `BEGIN;\n`;
    const manifestStr = fs.readFileSync(MANIFEST_PATH);
    const manifestHash = crypto.createHash('sha256').update(manifestStr).digest('hex');
    const importerSource = fs.readFileSync(__filename);
    const importerHash = crypto.createHash('sha256').update(importerSource).digest('hex');

    sql += `INSERT INTO data_imports.releases (id, release_name, source_uri, sha256_hash, status, manifest_hash) VALUES ('${releaseId}', 'LGD_20260826_CORE_R16', 'local://r16_loader_clean.js', '${importerHash}', 'PENDING', '213e1c5e08cd8f0c1be11bba049a29894ffec2297b28e1f30fcda375ab0d6ad8');\n`;

    let datasetHashConcat = '';
    for (let b of batches) {
        let bId = deterministicUuid(`batch-${releaseId}-${b}`);
        batchMap[b] = bId;
        
        let entityType = b.includes('BLOCK') ? 'BLOCK' : (b.includes('SUB_DISTRICT') ? 'SUB_DISTRICT' : (b.includes('DISTRICT') ? 'DISTRICT' : 'STATE'));
        let isDelhiBlock = b.includes('DELHI') && b.includes('BLOCK');
        let batchTotal = allData.filter(d => d.batchKey === b).length;
        let status = isDelhiBlock ? 'OFFICIAL_EMPTY' : 'STAGED';
        
        sql += `INSERT INTO data_imports.batches (id, release_id, logical_batch_key, entity_type, total_records, status) VALUES ('${bId}', '${releaseId}', '${b}', '${entityType}', ${batchTotal}, '${status}');\n`;
    }
    
    let batchInsert = [];
    let ordinal_counter = 1;
    for (let d of allData) {
        if (d.batchKey && d.batchKey.includes('DELHI') && d.batchKey.includes('BLOCK')) {
            continue;
        }
        
        let payloadStr = JSON.stringify(d.payload).replace(/'/g, "''");
        let rawPayloadSha256 = crypto.createHash('sha256').update(JSON.stringify(d.payload)).digest('hex');
        
        let bId = batchMap[d.batchKey];
        let obsKey = crypto.createHash('sha256').update(`${bId}-${d.file}-${d.phys}-${rawPayloadSha256}`).digest('hex');
        datasetHashConcat += obsKey;
        
        batchInsert.push(`('${releaseId}', '${bId}', '${d.entity}', '${d.file.replace(/'/g, "''")}', ${d.phys}, '${payloadStr}'::jsonb, 'CORE_GEOGRAPHY', 'OBS_V3', '${obsKey}', '${rawPayloadSha256}', '${d.physicalSourceSha256}', ${d.ordinal}, ${ordinal_counter})`);
        
        ordinal_counter++;
        
        if (batchInsert.length === 1000) {
            sql += `INSERT INTO staging.geography_imports (release_id, batch_id, entity_type, internal_member_or_sheet, physical_row_number, raw_data, observation_classification, observation_identity_version, source_observation_key, raw_payload_sha256, physical_source_sha256, logical_output_ordinal, emitted_record_ordinal) VALUES ${batchInsert.join(',')};\n`;
            batchInsert = [];
        }
    }
    if (batchInsert.length > 0) {
        sql += `INSERT INTO staging.geography_imports (release_id, batch_id, entity_type, internal_member_or_sheet, physical_row_number, raw_data, observation_classification, observation_identity_version, source_observation_key, raw_payload_sha256, physical_source_sha256, logical_output_ordinal, emitted_record_ordinal) VALUES ${batchInsert.join(',')};\n`;
    }
    
    sql += `COMMIT;\n`;
    
    const datasetSha256 = crypto.createHash('sha256').update(datasetHashConcat).digest('hex');
    fs.writeFileSync('D:/NAMISH_GLOBAL_CONTROL/supabase/migrations/20260901000002_r16_staging_load.sql', sql);
    
    console.log("R16_RELEASE_ID=" + releaseId);
    console.log("R16_IMPORTER_SHA256=" + importerHash);
    console.log("R16_MANIFEST_SHA256=" + manifestHash);
    console.log("R16_DATASET_SHA256=" + datasetSha256);
    console.log("R16_TOTAL_STAGED_ROWS=" + (ordinal_counter - 1));
}

run().catch(e => {
    console.error(e);
    process.exit(1);
});


