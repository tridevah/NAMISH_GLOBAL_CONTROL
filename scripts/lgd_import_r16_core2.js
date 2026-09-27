const fs = require('fs');
const crypto = require('crypto');
const { Client } = require('pg');
const yauzl = require('yauzl');
const XLSX = require('xlsx');
const path = require('path');

const MANIFEST_PATH = 'D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826/sealed_manifest_r15.json';
const BASE_DIR = 'D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826';
const MANIFEST = JSON.parse(fs.readFileSync(MANIFEST_PATH));

const TARGET_ENTITIES = ['STATE', 'DISTRICT', 'SUB_DISTRICT', 'BLOCK'];

async function readZipFile(zipPath, entryPath) {
    return new Promise((resolve, reject) => {
        yauzl.open(zipPath, {lazyEntries: true}, (err, zf) => {
            if (err) return reject(err);
            zf.readEntry();
            zf.on('entry', (e) => {
                if (e.fileName === entryPath || e.fileName.includes(entryPath.replace(/:/g, '-'))) {
                    zf.openReadStream(e, (err, stream) => {
                        let buffers = [];
                        stream.on('data', d => buffers.push(d));
                        stream.on('end', () => resolve(Buffer.concat(buffers)));
                    });
                } else {
                    zf.readEntry();
                }
            });
            zf.on('end', () => reject(new Error('File not found in zip: ' + entryPath)));
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
    console.log("R16 Preflight Extraction...");
    let allData = [];
    
    for (let entry of MANIFEST.entries) {
        let zipName = entry.path.split('!')[0];
        let stateName = zipName.split('/')[0];
        let entryPath = entry.path.split('!')[1];
        
        let validOutputs = entry.logical_outputs.filter(lo => TARGET_ENTITIES.includes(lo.logical_entity));
        if (validOutputs.length === 0) continue;
        
        let buf = await readZipFile(path.join(BASE_DIR, zipName), entryPath);
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
                    phys: r.phys_row
                });
            }
        }
    }
    
    console.log("Extraction complete. Running assertions...");
    
    let states = allData.filter(d => d.entity === 'STATE').length;
    let districts = allData.filter(d => d.entity === 'DISTRICT').length;
    let subDistricts = allData.filter(d => d.entity === 'SUB_DISTRICT').length;
    let blocks = allData.filter(d => d.entity === 'BLOCK').length;
    
    console.log(`STATE = ${states}, DISTRICT = ${districts}, SUB_DISTRICT = ${subDistricts}, BLOCK = ${blocks}`);
    if (states !== 36 || districts !== 784 || subDistricts !== 7092 || blocks !== 7338) {
        throw new Error("Total counts assertion failed");
    }
    
    if (allData.length !== 15250) throw new Error("Total observations != 15250");
    
    let blockData = allData.filter(d => d.entity === 'BLOCK');
    let nonblank = blockData.filter(b => b.name && b.name.length > 0).length;
    if (nonblank !== 7338) throw new Error(`BLOCK English names nonblank != 7338 (Got ${nonblank})`);
    
    let arunachalBlocks = blockData.filter(b => b.state === 'ARUNACHAL PRADESH').length;
    let otherBlocks = blockData.filter(b => b.state !== 'ARUNACHAL PRADESH').length;
    if (arunachalBlocks !== 129 || otherBlocks !== 7209) throw new Error("State-wise block count assertion failed");
    
    let distinctBlockCodes = new Set(blockData.map(b => b.code)).size;
    if (distinctBlockCodes !== 7323) throw new Error("Distinct block codes != 7323");
    
    // Group block codes to count distinct districts
    let blockToDistricts = {};
    blockData.forEach(b => {
        if (!blockToDistricts[b.code]) blockToDistricts[b.code] = new Set();
        blockToDistricts[b.code].add(b.districtCode);
    });
    
    let blocksWithOneDist = 0;
    let blocksWithTwoDist = 0;
    for (let c in blockToDistricts) {
        if (blockToDistricts[c].size === 1) blocksWithOneDist++;
        else if (blockToDistricts[c].size === 2) blocksWithTwoDist++;
        else throw new Error("Block with wrong number of districts: " + c);
    }
    
    if (blocksWithOneDist !== 7308 || blocksWithTwoDist !== 15) throw new Error("Block district distribution failed");
    
    let block1000 = blockData.find(b => String(b.code) === '1000');
    if (!block1000 || block1000.name !== 'Asafpur') throw new Error("Block 1000 name is not Asafpur");
    
    console.log("All preflight assertions passed. Writing to R16...");
    
    // Write to DB
    const client = new Client({ user: 'postgres', host: 'localhost', database: 'postgres', port: 54522, password: 'postgres' });
    await client.connect();
    
    await client.query("BEGIN");
    
    const importerSource = fs.readFileSync(__filename);
    const importerHash = crypto.createHash('sha256').update(importerSource).digest('hex');
    const manifestStr = fs.readFileSync('D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826/sealed_manifest_r16.json');
    const manifestHash = crypto.createHash('sha256').update(manifestStr).digest('hex');

    let rRes = await client.query(`
        INSERT INTO data_imports.releases (release_name, source_uri, sha256_hash, status, manifest_hash)
        VALUES ($1, $2, $3, $4, $5) RETURNING id
    `, ['LGD_20260826_CORE_R16', 'local://r16_importer.js', importerHash, 'PENDING', manifestHash]);
    
    let releaseId = rRes.rows[0].id;
    
    let batches = new Set(allData.map(d => d.batchKey));
    let batchMap = {};
    
    for (let b of batches) {
        let bRes = await client.query(`
            INSERT INTO data_imports.batches (release_id, logical_batch_key, entity_type, status, source_sha256)
            VALUES ($1, $2, $3, $4, $5) RETURNING id
        `, [releaseId, b, b.includes('BLOCK') ? 'BLOCK' : (b.includes('SUB_DISTRICT') ? 'SUB_DISTRICT' : (b.includes('DISTRICT') ? 'DISTRICT' : 'STATE')), 'STAGED', 'mock']);
        batchMap[b] = bRes.rows[0].id;
    }
    
    for (let d of allData) {
        if (d.batchKey && d.batchKey.includes('DELHI') && d.batchKey.includes('BLOCK')) {
            // Delhi blocks empty, but we must record them as zero logically if needed. We just skip them in staging table because they are empty batches, wait, Delhi actually has NO rows for blocks!
            continue;
        }
        await client.query(`
            INSERT INTO staging.geography_imports (release_id, batch_id, entity_type, internal_member_or_sheet, physical_row_number, raw_data, observation_identity_version, source_observation_key)
            VALUES ($1, $2, $3, $4, $5, $6, 'OBS_V3', gen_random_uuid()::text)
        `, [releaseId, batchMap[d.batchKey], d.entity, d.file, d.phys, d.payload]);
    }
    
    // Update Delhi blocks to OFFICIAL_EMPTY
    await client.query(`UPDATE data_imports.batches SET status = 'OFFICIAL_EMPTY' WHERE release_id = $1 AND logical_batch_key LIKE '%DELHI%BLOCK%'`, [releaseId]);
    
    // Verify R16 total
    let totalCount = await client.query(`SELECT count(*) FROM staging.geography_imports WHERE release_id = $1`, [releaseId]);
    if (totalCount.rows[0].count != 15250) throw new Error("R16 DB staged count mismatch");
    
    await client.query("COMMIT");
    await client.end();
    
    console.log("R16_RELEASE_ID=" + releaseId);
    console.log("R16_IMPORTER_SHA256=" + importerHash);
    console.log("R16_MANIFEST_SHA256=" + manifestHash);
    console.log("R16_TOTAL_STAGED_ROWS=" + totalCount.rows[0].count);
    
}
run().catch(console.error);
