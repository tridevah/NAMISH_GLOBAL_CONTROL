const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const XLSX = require('xlsx');
const AdmZip = require('adm-zip');

const BASE_DIR = path.join(__dirname, '../r16_source');
const MANIFEST_PATH = path.join(BASE_DIR, 'sealed_manifest_r16.json');
const MANIFEST = JSON.parse(fs.readFileSync(MANIFEST_PATH, 'utf8'));

const TARGET_ENTITIES = ['STATE', 'DISTRICT', 'SUB_DISTRICT', 'BLOCK'];

function deterministicUuid(str) {
    const hash = crypto.createHash('sha1').update(str).digest('hex');
    return [
        hash.substring(0, 8),
        hash.substring(8, 12),
        '5' + hash.substring(13, 16),
        (parseInt(hash.substring(16, 17), 16) & 0x3 | 0x8).toString(16) + hash.substring(17, 20),
        hash.substring(20, 32)
    ].join('-');
}

async function readZipFile(zipPath, entryPath) {
    const zip = new AdmZip(zipPath);
    const entry = zip.getEntries().find(e => e.entryName === entryPath);
    if (!entry) throw new Error(`Entry ${entryPath} not found in ${zipPath}`);
    return entry.getData();
}

async function parseSheet(buf, entityType, stateName) {
    let wb = XLSX.read(buf, {type: 'buffer'});
    let ws = wb.Sheets[wb.SheetNames[0]];
    let rawRows = XLSX.utils.sheet_to_json(ws, {header: 1, defval: ''});
    
    if (entityType === 'STATE') {
        let titleRow = '';
        for (let r = 0; r < 5; r++) {
            if (rawRows[r] && rawRows[r][0] && typeof rawRows[r][0] === 'string' && rawRows[r][0].toLowerCase().includes('state code')) {
                titleRow = String(rawRows[r][0]);
                break;
            }
        }
        if (!titleRow) titleRow = String(rawRows[1] ? rawRows[1][0] : rawRows[0][0]);
        return [{ phys_row: 2, raw: { TITLE: titleRow } }];
    }

    let headerIdx = rawRows.findIndex(r => r[0] && (String(r[0]).toLowerCase().includes('s.no') || String(r[0]).toLowerCase().includes('s. no')));
    if (headerIdx === -1) throw new Error("Could not find header row");
    
    let header = rawRows[headerIdx].map(c => String(c).toLowerCase().trim().replace(/\r?\n/g, ' '));
    let dataRows = [];
    
    for (let i = headerIdx + 1; i < rawRows.length; i++) {
        let r = rawRows[i];
        if (!r[0] || String(r[0]).toLowerCase().includes('note')) continue;
        
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

            header.forEach((h, idx) => {
                let key = h;
                if (obj[key] !== undefined) key = key + '_' + idx;
                obj[key] = r[idx];
            });
        }
        
        dataRows.push({ phys_row: i + 1, raw: obj });
    }
    return dataRows;
}

async function run() {
    let allData = [];
    let batches = new Set();
    
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
                if (lo.logical_entity === 'BLOCK') codeKey = Object.keys(r.raw).find(k => k.includes('block code') || k.includes('development block code'));
                if (lo.logical_entity === 'DISTRICT') codeKey = Object.keys(r.raw).find(k => k === 'district code');
                
                let code = codeKey ? r.raw[codeKey] : null;
                if (lo.logical_entity === 'STATE') code = r.raw.TITLE;
                
                let distCodeKey = Object.keys(r.raw).find(k => k === 'district code');
                
                allData.push({
                    state: stateName,
                    entity: lo.logical_entity,
                    code: code,
                    districtCode: distCodeKey ? r.raw[distCodeKey] : null,
                    name: r.raw['block name'] || r.raw['development block name (in english)'] || r.raw['sub-district name (in english)'] || r.raw['subdistrict name (in english)'] || r.raw['district name (in english)'] || r.raw['district name'],
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
    
    let releaseId = '5fac63d7-0101-43c5-8867-bd75ff609861';
    let batchMap = {};
    for (let d of allData) batches.add(d.batchKey);
    for (let b of batches) {
        let bId = deterministicUuid(`batch-${releaseId}-${b}`);
        batchMap[b] = bId;
    }
    
    let stateMap = {};
    for (let d of allData) {
        if (d.entity === 'STATE') {
            let match = d.code.match(/State Code\s*:\s*(\d+)/i);
            if (match) {
                stateMap[d.state] = match[1];
            }
        }
    }
    
    let sql = `BEGIN ISOLATION LEVEL SERIALIZABLE;\n`;
    sql += `SELECT pg_advisory_xact_lock(hashtext('LGD_CORE_R16_REHEARSAL'));\n`;
    sql += `SET search_path TO catalog, staging, data_imports, public;\n`;
    sql += `SET CONSTRAINTS ALL IMMEDIATE;\n\n`;

    sql += `CREATE TEMPORARY TABLE _r16_norm (
        entity_type text,
        internal_member_or_sheet text,
        physical_row_number int,
        entity_code text,
        entity_name text,
        parent_code text
    ) ON COMMIT DROP;\n\n`;

    let values = [];
    
    for (let d of allData) {
        if (d.batchKey && d.batchKey.includes('DELHI') && d.batchKey.includes('BLOCK')) {
            continue; 
        }
        
        let eCode = 'NULL';
        let eName = 'NULL';
        let pCode = 'NULL';
        
        if (d.entity === 'STATE') {
            eCode = stateMap[d.state] ? `'${stateMap[d.state]}'` : 'NULL';
            eName = `'${d.state.replace(/'/g, "''")}'`;
        } else if (d.entity === 'DISTRICT') {
            let codeKey = Object.keys(d.payload).find(k => k === 'district code');
            let nameKey = Object.keys(d.payload).find(k => k.includes('district name'));
            let codeVal = codeKey ? d.payload[codeKey] : null;
            let nameVal = nameKey ? d.payload[nameKey] : '';
            eCode = codeVal ? `'${codeVal}'` : 'NULL';
            eName = nameVal ? `'${String(nameVal).replace(/'/g, "''")}'` : 'NULL';
            pCode = stateMap[d.state] ? `'${stateMap[d.state]}'` : 'NULL';
        } else if (d.entity === 'SUB_DISTRICT') {
            let codeKey = Object.keys(d.payload).find(k => k.includes('sub-district code') || k.includes('subdistrict code'));
            let nameKey = Object.keys(d.payload).find(k => k.includes('sub-district name') || k.includes('subdistrict name'));
            let pKey = Object.keys(d.payload).find(k => k === 'district code');
            let codeVal = codeKey ? d.payload[codeKey] : null;
            let nameVal = nameKey ? d.payload[nameKey] : '';
            
            // Explicit source correction: 5916 = Car Nicobar (missing in staging payload)
            if (codeVal == '5916' || codeVal == 5916) {
                nameVal = 'Car Nicobar';
            }
            
            eCode = codeVal ? `'${codeVal}'` : 'NULL';
            eName = nameVal ? `'${String(nameVal).replace(/'/g, "''")}'` : 'NULL';
            pCode = pKey && d.payload[pKey] ? `'${d.payload[pKey]}'` : 'NULL';
        } else if (d.entity === 'BLOCK') {
            let codeKey = Object.keys(d.payload).find(k => k.includes('block code') || k.includes('development block code'));
            let nameKey = Object.keys(d.payload).find(k => k.includes('block name') || k.includes('development block name (in english)'));
            let pKey = Object.keys(d.payload).find(k => k === 'district code');
            let codeVal = codeKey ? d.payload[codeKey] : null;
            let nameVal = nameKey ? d.payload[nameKey] : '';
            eCode = codeVal ? `'${codeVal}'` : 'NULL';
            eName = nameVal ? `'${String(nameVal).replace(/'/g, "''")}'` : 'NULL';
            pCode = pKey && d.payload[pKey] ? `'${d.payload[pKey]}'` : 'NULL';
        }
        
        let safeFile = d.file.replace(/'/g, "''");
        values.push(`('${d.entity}', '${safeFile}', ${d.phys}, ${eCode}, ${eName}, ${pCode})`);
    }
    
    const chunkSize = 1000;
    for (let i = 0; i < values.length; i += chunkSize) {
        const chunk = values.slice(i, i + chunkSize);
        if (i === 0) {
            sql += `INSERT INTO _r16_norm (entity_type, internal_member_or_sheet, physical_row_number, entity_code, entity_name, parent_code) VALUES\n`;
        } else {
            sql += `INSERT INTO _r16_norm (entity_type, internal_member_or_sheet, physical_row_number, entity_code, entity_name, parent_code) VALUES\n`;
        }
        sql += chunk.join(',\n') + ';\n\n';
    }
    
    sql += `
DO $$
DECLARE
    india_id uuid;
    state_lvl uuid;
    district_lvl uuid;
    subdistrict_lvl uuid;
    c_state int; c_dist int; c_subdist int; c_block int; c_rel int;
    i_dist int; i_subdist int; i_block int; i_rel int;
    err_rec jsonb;
    v_release_id uuid := '5fac63d7-0101-43c5-8867-bd75ff609861';
    unmatched_count int;
BEGIN
    SELECT count(*) INTO unmatched_count FROM staging.geography_imports s LEFT JOIN _r16_norm n ON n.entity_type = s.entity_type AND n.internal_member_or_sheet = s.internal_member_or_sheet AND n.physical_row_number = s.physical_row_number WHERE s.release_id = v_release_id AND s.batch_id NOT IN (SELECT id FROM data_imports.batches WHERE logical_batch_key LIKE '%DELHI%BLOCK%') AND n.internal_member_or_sheet IS NULL;
    IF unmatched_count > 0 THEN RAISE EXCEPTION 'Identity binding failed. % staging rows unmatched.', unmatched_count; END IF;

    SELECT id INTO state_lvl FROM catalog.geography_levels WHERE level_key = 'STATE_UT';
    SELECT country_id INTO india_id FROM catalog.geography_units WHERE geography_level_id = state_lvl LIMIT 1;
    SELECT id INTO district_lvl FROM catalog.geography_levels WHERE level_key = 'DISTRICT';
    SELECT id INTO subdistrict_lvl FROM catalog.geography_levels WHERE level_key = 'SUB_DISTRICT';

    SELECT row_to_json(n) INTO err_rec FROM _r16_norm n WHERE n.entity_code IS NULL OR n.entity_name IS NULL OR (n.entity_type != 'STATE' AND n.parent_code IS NULL) LIMIT 1;
    IF FOUND THEN RAISE EXCEPTION 'Normalized field blank/missing: %', err_rec; END IF;
    
    SELECT row_to_json(n) INTO err_rec FROM _r16_norm n LEFT JOIN catalog.geography_units p ON p.official_code = n.parent_code AND p.geography_level_id = state_lvl WHERE n.entity_type = 'DISTRICT' AND p.id IS NULL LIMIT 1;
    IF FOUND THEN RAISE EXCEPTION 'DISTRICT parent unresolved: %', err_rec; END IF;

    WITH valid_districts AS (SELECT n.entity_code, n.entity_name, p.id AS parent_id FROM _r16_norm n JOIN catalog.geography_units p ON p.official_code = n.parent_code AND p.geography_level_id = state_lvl WHERE n.entity_type = 'DISTRICT'),
    new_districts AS (SELECT v.* FROM valid_districts v LEFT JOIN catalog.geography_units e ON e.official_code = v.entity_code AND e.geography_level_id = district_lvl WHERE e.id IS NULL),
    inserted_d AS (INSERT INTO catalog.geography_units (country_id, geography_level_id, parent_geography_unit_id, official_code, official_name, display_name, status) SELECT india_id, district_lvl, parent_id, entity_code, entity_name, entity_name, 'ACTIVE' FROM new_districts RETURNING 1)
    SELECT count(*) INTO i_dist FROM inserted_d;

    WITH valid_subdists AS (SELECT n.entity_code, n.entity_name, p.id AS parent_id FROM _r16_norm n JOIN catalog.geography_units p ON p.official_code = n.parent_code AND p.geography_level_id = district_lvl WHERE n.entity_type = 'SUB_DISTRICT'),
    new_subdists AS (SELECT v.* FROM valid_subdists v LEFT JOIN catalog.geography_units e ON e.official_code = v.entity_code AND e.geography_level_id = subdistrict_lvl WHERE e.id IS NULL),
    inserted_s AS (INSERT INTO catalog.geography_units (country_id, geography_level_id, parent_geography_unit_id, official_code, official_name, display_name, status) SELECT india_id, subdistrict_lvl, parent_id, entity_code, entity_name, entity_name, 'ACTIVE' FROM new_subdists RETURNING 1)
    SELECT count(*) INTO i_subdist FROM inserted_s;

    WITH valid_blocks AS (SELECT DISTINCT entity_code::int AS code_int, entity_code, entity_name FROM _r16_norm WHERE entity_type = 'BLOCK'),
    new_blocks AS (SELECT v.* FROM valid_blocks v LEFT JOIN catalog.development_blocks e ON e.official_code = v.entity_code WHERE e.id IS NULL),
    inserted_b AS (INSERT INTO catalog.development_blocks (id, official_code, official_name, status) SELECT gen_random_uuid(), entity_code, entity_name, 'ACTIVE' FROM new_blocks RETURNING 1)
    SELECT count(*) INTO i_block FROM inserted_b;

    WITH valid_rels AS (SELECT DISTINCT n.entity_code, n.parent_code FROM _r16_norm n WHERE n.entity_type = 'BLOCK'),
    mapped_rels AS (SELECT b.id AS block_id, d.id AS dist_id FROM valid_rels r JOIN catalog.development_blocks b ON b.official_code = r.entity_code JOIN catalog.geography_units d ON d.official_code = r.parent_code AND d.geography_level_id = district_lvl),
    new_rels AS (SELECT m.* FROM mapped_rels m LEFT JOIN catalog.block_districts e ON e.block_id = m.block_id AND e.district_id = m.dist_id WHERE e.block_id IS NULL),
    inserted_r AS (INSERT INTO catalog.block_districts (block_id, district_id, source_release_id) SELECT block_id, dist_id, v_release_id FROM new_rels RETURNING 1)
    SELECT count(*) INTO i_rel FROM inserted_r;

    SELECT count(*) INTO c_state FROM catalog.geography_units WHERE geography_level_id = state_lvl;
    SELECT count(*) INTO c_dist FROM catalog.geography_units WHERE geography_level_id = district_lvl;
    SELECT count(*) INTO c_subdist FROM catalog.geography_units WHERE geography_level_id = subdistrict_lvl;
    SELECT count(*) INTO c_block FROM catalog.development_blocks;
    SELECT count(*) INTO c_rel FROM catalog.block_districts;

    IF c_state != 36 THEN RAISE EXCEPTION 'Assert Failed: States = %', c_state; END IF;
    IF c_dist != 784 THEN RAISE EXCEPTION 'Assert Failed: Districts = %', c_dist; END IF;
    IF c_subdist != 7092 THEN RAISE EXCEPTION 'Assert Failed: SubDistricts = %', c_subdist; END IF;
    IF c_block != 7323 THEN RAISE EXCEPTION 'Assert Failed: Blocks = %', c_block; END IF;
    IF c_rel != 7338 THEN RAISE EXCEPTION 'Assert Failed: Rels = %', c_rel; END IF;
    
    DECLARE
        bd_1 int;
        bd_2 int;
    BEGIN
        SELECT count(*) INTO bd_1 FROM (SELECT block_id FROM catalog.block_districts GROUP BY block_id HAVING count(*) = 1) sub;
        SELECT count(*) INTO bd_2 FROM (SELECT block_id FROM catalog.block_districts GROUP BY block_id HAVING count(*) = 2) sub;
        IF bd_1 != 7308 THEN RAISE EXCEPTION 'Assert Failed: bd1 = %', bd_1; END IF;
        IF bd_2 != 15 THEN RAISE EXCEPTION 'Assert Failed: bd2 = %', bd_2; END IF;
    END;

    RAISE EXCEPTION 'SUCCESS|%|%|%|%', COALESCE(i_dist,0), COALESCE(i_subdist,0), COALESCE(i_block,0), COALESCE(i_rel,0);
END;
$$;
ROLLBACK;
`;

    fs.writeFileSync(path.join(__dirname, '../r16_cli_dryrun_20260901_183500/supabase/migrations/20260901000003_r16_promotion_rehearsal.sql'), sql);
}

run().catch(console.error);
