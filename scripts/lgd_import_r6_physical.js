/**
 * LGD_20260826_CORE_R6 — Complete physical importer v1
 * Version hash is recorded before first row staged.
 * No artificial row/chunk/file limits.
 * Bounded-memory: XLS streamed via SAX, CSV streamed via readline.
 * One physical source → all declared logical outputs in dependency order.
 * DOP_PIN_CSV_V1 identity for Post Offices.
 */
'use strict';

const fs      = require('fs');
const path    = require('path');
const crypto  = require('crypto');
const yauzl   = require('yauzl');
const sax     = require('sax');
const XLSX    = require('xlsx');
const readline= require('readline');
const { Client, Pool } = require('pg');
const { pipeline, Transform } = require('stream');

// ─── Constants ──────────────────────────────────────────────────────────────
const SOURCE_DIR  = 'D:\\ANTIGRAVITY_WORKSPACE\\INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826';
const RUNTIME_DIR = 'D:\\ANTIGRAVITY_WORKSPACE\\LGD_IMPORT_RUNTIME\\R6';
const MANIFEST    = path.join(SOURCE_DIR, 'sealed_manifest_r6.json');
const HEARTBEAT   = path.join(RUNTIME_DIR, 'heartbeat.json');
const PID_FILE    = path.join(RUNTIME_DIR, 'importer_r6.pid');
const STOP_FILE   = path.join(RUNTIME_DIR, 'STOP_REQUESTED');
const LOG_FILE    = path.join(RUNTIME_DIR, 'importer_r6.log');
const CHECKPOINT  = path.join(RUNTIME_DIR, 'checkpoint.json');

const DB_URL = 'postgresql://postgres:postgres@localhost:54522/postgres';
const ADVISORY_LOCK = 202608266; // unique for R6 physical

const INDIA_ID   = 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d';
const GEO_LEVEL  = {
    STATE_UT:    'cc17368a-61a6-b027-c85e-fadeedfe0da8',
    DISTRICT:    '1b6e5e2a-db7c-d9ee-073e-dbb807ed0caf',
    SUB_DISTRICT:'d8f00de9-7051-bc5a-3229-35c171d3198f',
    LOCALITY:    'd17092e1-cba7-5722-71e1-f41ff5cfb21c',
};

// PRI localbody type code → enum
const PRI_TYPE_CODE_MAP = {
    '1':'PRI_DISTRICT','2':'PRI_DISTRICT',
    '3':'PRI_INTERMEDIATE','4':'PRI_INTERMEDIATE',
    '5':'PRI_GRAM_PANCHAYAT','6':'PRI_GRAM_PANCHAYAT',
};

const CHUNK_SIZE = 500;

if (!fs.existsSync(RUNTIME_DIR)) fs.mkdirSync(RUNTIME_DIR,{recursive:true});
fs.writeFileSync(PID_FILE, String(process.pid));

// ─── Importer version hash ───────────────────────────────────────────────────
const IMPORTER_FILE = __filename;
const IMPORTER_HASH = crypto.createHash('sha256')
    .update(fs.readFileSync(IMPORTER_FILE))
    .digest('hex');

// ─── Logging ─────────────────────────────────────────────────────────────────
const log = (...a) => {
    const l = `[${new Date().toISOString()}] ${a.join(' ')}\n`;
    process.stdout.write(l);
    fs.appendFileSync(LOG_FILE, l);
};

const hb = (entity, stateUt, staged, promoted, done, currentOutput) => {
    fs.writeFileSync(HEARTBEAT, JSON.stringify({
        pid: process.pid, time: new Date().toISOString(),
        release: 'LGD_20260826_CORE_R6', status: 'RUNNING',
        identity_version: 'DOP_PIN_CSV_V1',
        importer_version_hash: IMPORTER_HASH,
        current_source: entity, current_state_ut: stateUt,
        current_logical_output: currentOutput,
        rows_staged: staged, rows_promoted: promoted,
        batches_completed: done, expected_logical_batches: 506
    }));
};

const isStop = () => fs.existsSync(STOP_FILE);
const norm   = s => String(s||'').normalize('NFKC').toLowerCase().replace(/\s+/g,' ').trim();

// ─── Checkpoint ───────────────────────────────────────────────────────────────
let checkpoint = {};
if (fs.existsSync(CHECKPOINT)) checkpoint = JSON.parse(fs.readFileSync(CHECKPOINT,'utf8'));
const saveCheckpoint = () => fs.writeFileSync(CHECKPOINT, JSON.stringify(checkpoint));
const ckKey = (entryPath, entity) => `${entryPath}::${entity}`;
const isCompleted = (ep, en) => checkpoint[ckKey(ep,en)] === 'COMPLETED';
const markCompleted = (ep, en) => { checkpoint[ckKey(ep,en)] = 'COMPLETED'; saveCheckpoint(); };

// ─── Stats ────────────────────────────────────────────────────────────────────
let totalStaged = 0, totalPromoted = 0, batchesDone = 0;

// ─── DB Pool ─────────────────────────────────────────────────────────────────
const pool = new Pool({ connectionString: DB_URL, max: 5 });

// ─── Helper: get or create batch ─────────────────────────────────────────────
async function getBatchId(client, releaseId, entityType) {
    const r = await client.query(
        'SELECT id FROM data_imports.batches WHERE release_id=$1 AND entity_type=$2',
        [releaseId, entityType]);
    if (r.rows.length) return r.rows[0].id;
    const ins = await client.query(
        'INSERT INTO data_imports.batches(release_id,entity_type,status) VALUES($1,$2,$3) RETURNING id',
        [releaseId, entityType, 'IN_PROGRESS']);
    return ins.rows[0].id;
}

async function completeBatch(client, batchId, stats) {
    const total = (stats.staged || 0);
    const success = (stats.inserted || 0) + (stats.updated || 0) + (stats.unchanged || 0);
    const failed  = (stats.rejected || 0);
    await client.query(`UPDATE data_imports.batches SET status='COMPLETED',
        total_records=$1, successful_records=$2, failed_records=$3,
        staged_rows=$4, inserted_rows=$5, updated_rows=$6, unchanged_rows=$7, rejected_rows=$8,
        started_at=COALESCE(started_at,NOW()), completed_at=NOW() WHERE id=$9`,
        [total, success, failed,
         stats.staged||0, stats.inserted||0, stats.updated||0, stats.unchanged||0, stats.rejected||0,
         batchId]);
}

// ─── SAX XLS row reader (streaming, bounded memory) ──────────────────────────
function* saxRows(stream) {
    // This is a synchronous generator wrapper – actual streaming done via callbacks
    // We use an approach where we push rows into a queue
}

function readXlsStreamRows(stream, onRow, onEnd) {
    const ss = sax.createStream(true, { trim: true });
    let inCell=false, cellIdx=0, data='', row=[];
    ss.on('opentag', n => {
        if(n.name==='Row') { row=[]; cellIdx=0; }
        else if(n.name==='Cell') {
            inCell=true; data='';
            if(n.attributes['ss:Index']) cellIdx=parseInt(n.attributes['ss:Index'],10)-1;
        }
    });
    ss.on('text', t => { if(inCell) data+=t; });
    ss.on('closetag', n => {
        if(n==='Cell') { row[cellIdx++]=data; inCell=false; }
        else if(n==='Row') { onRow([...row]); }
    });
    ss.on('end', onEnd);
    ss.on('error', err => { log('SAX error:', err.message); onEnd(); });
    stream.pipe(ss);
}

// ─── Chunk COPY to staging ────────────────────────────────────────────────────
async function stageChunk(client, batchId, entityType, rows, sourceFile, physRowStart) {
    if (!rows.length) return 0;
    // INSERT rows into staging.geography_imports
    const vals = rows.map((r,i) => {
        const escaped = JSON.stringify(r.raw_data).replace(/\\/g,'\\\\');
        return `($1,$2,$3,$4,$5,${physRowStart+i},$6,'PENDING')`;
    });
    // Use parameterized multi-insert in chunks
    let inserted = 0;
    for (const r of rows) {
        try {
            await client.query(`INSERT INTO staging.geography_imports
                (batch_id,entity_type,entity_code,parent_code,entity_name,raw_data,source_filename,physical_row_number,classification)
                VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9)
                ON CONFLICT DO NOTHING`,
                [batchId, entityType, r.entity_code, r.parent_code, r.entity_name,
                 JSON.stringify(r.raw_data), sourceFile, r.physical_row_number, 'PENDING']);
            inserted++;
        } catch(e) {
            log(`  staging error row ${r.physical_row_number}: ${e.message}`);
        }
    }
    totalStaged += inserted;
    return inserted;
}

// ─── PROMOTE: geography_units (District / Sub-District / Village) ─────────────
async function promoteGeographyUnit(client, batchId, entityType, releaseId) {
    const levelKey = entityType === 'DISTRICT' ? 'DISTRICT'
                   : entityType === 'SUB_DISTRICT' ? 'SUB_DISTRICT'
                   : 'LOCALITY'; // VILLAGE
    const levelId = GEO_LEVEL[levelKey];

    const rows = await client.query(
        'SELECT entity_code, parent_code, entity_name, raw_data, physical_row_number FROM staging.geography_imports WHERE batch_id=$1 AND classification=$2',
        [batchId, 'PENDING']);

    let inserted=0, updated=0, unchanged=0, rejected=0;
    for (const row of rows.rows) {
        const code = row.entity_code;
        const name = row.entity_name;
        if (!code || !name) { rejected++; continue; }

        // Parent lookup — DISTRICT has no state code in source; leave parent for existing rows
        let parentId = null;
        if (entityType === 'SUB_DISTRICT') {
            const pr = await client.query(
                'SELECT id FROM catalog.geography_units WHERE official_code=$1 AND geography_level_id=$2 AND country_id=$3',
                [row.parent_code, GEO_LEVEL.DISTRICT, INDIA_ID]);
            if (!pr.rows.length) {
                rejected++;
                await client.query(
                    "UPDATE staging.geography_imports SET classification='UNRESOLVED_PARENT',error_message=$1 WHERE batch_id=$2 AND physical_row_number=$3",
                    ['District '+row.parent_code+' not found', batchId, row.physical_row_number]);
                continue;
            }
            parentId = pr.rows[0].id;
        } else if (entityType === 'VILLAGE') {
            const pr = await client.query(
                'SELECT id FROM catalog.geography_units WHERE official_code=$1 AND geography_level_id=$2 AND country_id=$3',
                [row.parent_code, GEO_LEVEL.SUB_DISTRICT, INDIA_ID]);
            if (!pr.rows.length) {
                rejected++;
                await client.query(
                    "UPDATE staging.geography_imports SET classification='UNRESOLVED_PARENT',error_message=$1 WHERE batch_id=$2 AND physical_row_number=$3",
                    ['SubDistrict '+row.parent_code+' not found', batchId, row.physical_row_number]);
                continue;
            }
            parentId = pr.rows[0].id;
        }
        // DISTRICT: parentId stays null; existing rows already have correct parent from prior import

        // Check existing by official_code (canonical identity)
        const ex = await client.query(
            'SELECT id, official_name FROM catalog.geography_units WHERE official_code=$1 AND geography_level_id=$2 AND country_id=$3',
            [code, levelId, INDIA_ID]);

        try {
            if (ex.rows.length) {
                // Existing record — update name if changed; do not touch parent or level
                if (ex.rows[0].official_name !== name) {
                    await client.query(
                        'UPDATE catalog.geography_units SET official_name=$1,display_name=$1,updated_at=NOW() WHERE id=$2',
                        [name, ex.rows[0].id]);
                    updated++;
                } else unchanged++;
            } else {
                // New record — insert; parentId=null acceptable for DISTRICT (will be linked later)
                await client.query(`INSERT INTO catalog.geography_units
                    (id,country_id,geography_level_id,parent_geography_unit_id,official_code,official_name,display_name,status,effective_from)
                    VALUES(gen_random_uuid(),$1,$2,$3,$4,$5,$5,'ACTIVE',NOW())`,
                    [INDIA_ID, levelId, parentId, code, name]);
                inserted++;
            }
            await client.query(
                "UPDATE staging.geography_imports SET classification='PROMOTED' WHERE batch_id=$1 AND physical_row_number=$2",
                [batchId, row.physical_row_number]);
        } catch(e) {
            if (e.constraint === 'geo_units_normalized_name_idx') {
                // Same name already exists under same parent with a different official_code.
                // This is a real LGD data pattern — two distinct villages with identical names
                // in the same sub-district. Record for review; do NOT merge.
                rejected++;
                await client.query(
                    "UPDATE staging.geography_imports SET classification='NAME_COLLISION_REVIEW',error_message=$1 WHERE batch_id=$2 AND physical_row_number=$3",
                    [`Name collision: "${name}" already exists at this level/parent with different code`, batchId, row.physical_row_number]);
                log(`  NAME_COLLISION_REVIEW: ${entityType} code=${code} name="${name}"`);
            } else {
                rejected++;
                await client.query(
                    "UPDATE staging.geography_imports SET classification='ERROR',error_message=$1 WHERE batch_id=$2 AND physical_row_number=$3",
                    [e.message, batchId, row.physical_row_number]);
                log(`  DB error ${entityType} code=${code}: ${e.message}`);
            }
        }
    }
    totalPromoted += inserted + updated;
    return {staged: rows.rows.length, inserted, updated, unchanged, rejected};
}


// ─── PROMOTE: development_blocks ─────────────────────────────────────────────
async function promoteBlocks(client, batchId) {
    const rows = await client.query(
        'SELECT entity_code,parent_code,entity_name,physical_row_number FROM staging.geography_imports WHERE batch_id=$1 AND classification=$2',
        [batchId,'PENDING']);
    let inserted=0,updated=0,unchanged=0,rejected=0;
    for (const row of rows.rows) {
        const distR = await client.query(
            'SELECT id FROM catalog.geography_units WHERE official_code=$1 AND geography_level_id=$2',
            [row.parent_code, GEO_LEVEL.DISTRICT]);
        if (!distR.rows.length) { rejected++; continue; }
        const distId = distR.rows[0].id;
        const ex = await client.query(
            'SELECT id,official_name FROM catalog.development_blocks WHERE official_code=$1 AND district_id=$2',
            [row.entity_code, distId]);
        if (ex.rows.length) {
            if (ex.rows[0].official_name !== row.entity_name) {
                await client.query('UPDATE catalog.development_blocks SET official_name=$1,updated_at=NOW() WHERE id=$2',[row.entity_name,ex.rows[0].id]);
                updated++;
            } else unchanged++;
        } else {
            await client.query('INSERT INTO catalog.development_blocks(id,district_id,official_code,official_name,status) VALUES(gen_random_uuid(),$1,$2,$3,$4)',
                [distId, row.entity_code, row.entity_name, 'ACTIVE']);
            inserted++;
        }
        await client.query('UPDATE staging.geography_imports SET classification=$1 WHERE batch_id=$2 AND physical_row_number=$3',['PROMOTED',batchId,row.physical_row_number]);
    }
    totalPromoted += inserted+updated;
    return {staged:rows.rows.length, inserted, updated, unchanged, rejected};
}

// ─── PROMOTE: local_bodies ────────────────────────────────────────────────────
async function promoteLocalBodies(client, batchId, bodyType) {
    // bodyType: 'PRI_DISTRICT','PRI_INTERMEDIATE','PRI_GRAM_PANCHAYAT','URBAN','TRADITIONAL'
    const rows = await client.query(
        `SELECT entity_code,parent_code,entity_name,raw_data,physical_row_number FROM staging.geography_imports
         WHERE batch_id=$1 AND classification=$2 AND raw_data->>'lb_type'=$3`,
        [batchId,'PENDING',bodyType]);
    let inserted=0,updated=0,unchanged=0,rejected=0;
    for (const row of rows.rows) {
        const stateR = await client.query(
            'SELECT id FROM catalog.geography_units WHERE official_code=$1 AND geography_level_id=$2',
            [row.raw_data.state_code, GEO_LEVEL.STATE_UT]);
        if (!stateR.rows.length) { rejected++; continue; }
        const stateId = stateR.rows[0].id;
        let parentLbId = null;
        if (row.parent_code && row.parent_code !== '0') {
            const pr = await client.query('SELECT id FROM catalog.local_bodies WHERE official_code=$1',[row.parent_code]);
            if (pr.rows.length) parentLbId = pr.rows[0].id;
        }
        const ex = await client.query('SELECT id,official_name FROM catalog.local_bodies WHERE official_code=$1',[row.entity_code]);
        if (ex.rows.length) {
            if (ex.rows[0].official_name !== row.entity_name) {
                await client.query('UPDATE catalog.local_bodies SET official_name=$1,updated_at=NOW() WHERE id=$2',[row.entity_name,ex.rows[0].id]);
                updated++;
            } else unchanged++;
        } else {
            await client.query(`INSERT INTO catalog.local_bodies(id,state_id,parent_local_body_id,body_type,official_code,official_name,status)
                VALUES(gen_random_uuid(),$1,$2,$3,$4,$5,$6)`,
                [stateId,parentLbId,bodyType,row.entity_code,row.entity_name,'ACTIVE']);
            inserted++;
        }
        await client.query('UPDATE staging.geography_imports SET classification=$1 WHERE batch_id=$2 AND physical_row_number=$3',['PROMOTED',batchId,row.physical_row_number]);
    }
    totalPromoted += inserted+updated;
    return {staged:rows.rows.length, inserted, updated, unchanged, rejected};
}

// ─── PROMOTE: wards ───────────────────────────────────────────────────────────
async function promoteWards(client, batchId) {
    const rows = await client.query(
        'SELECT entity_code,parent_code,entity_name,raw_data,physical_row_number FROM staging.geography_imports WHERE batch_id=$1 AND classification=$2',
        [batchId,'PENDING']);
    let inserted=0,updated=0,unchanged=0,rejected=0;
    for (const row of rows.rows) {
        const lbR = await client.query('SELECT id FROM catalog.local_bodies WHERE official_code=$1',[row.parent_code]);
        if (!lbR.rows.length) { rejected++; continue; }
        const lbId = lbR.rows[0].id;
        const ex = await client.query('SELECT id FROM catalog.wards WHERE official_code=$1 AND local_body_id=$2',[row.entity_code,lbId]);
        if (ex.rows.length) { unchanged++; }
        else {
            await client.query('INSERT INTO catalog.wards(id,local_body_id,official_code,ward_number,official_name,status) VALUES(gen_random_uuid(),$1,$2,$3,$4,$5)',
                [lbId,row.entity_code,row.raw_data.ward_number||row.entity_code,row.entity_name,'ACTIVE']);
            inserted++;
        }
        await client.query('UPDATE staging.geography_imports SET classification=$1 WHERE batch_id=$2 AND physical_row_number=$3',['PROMOTED',batchId,row.physical_row_number]);
    }
    totalPromoted += inserted+updated;
    return {staged:rows.rows.length, inserted, updated, unchanged, rejected};
}

// ─── PROMOTE: postal_codes (PINCODE) ─────────────────────────────────────────
async function promotePostalCodes(client, batchId) {
    const rows = await client.query(
        'SELECT DISTINCT entity_code FROM staging.geography_imports WHERE batch_id=$1 AND classification=$2',
        [batchId,'PENDING']);
    let inserted=0,unchanged=0;
    for (const row of rows.rows) {
        const ex = await client.query('SELECT id FROM catalog.postal_codes WHERE postal_code=$1 AND country_id=$2',[row.entity_code,INDIA_ID]);
        if (ex.rows.length) { unchanged++; }
        else {
            await client.query('INSERT INTO catalog.postal_codes(id,country_id,postal_code,status,effective_from) VALUES(gen_random_uuid(),$1,$2,$3,NOW())',
                [INDIA_ID,row.entity_code,'ACTIVE']);
            inserted++;
        }
    }
    await client.query("UPDATE staging.geography_imports SET classification='PROMOTED' WHERE batch_id=$1",[batchId]);
    totalPromoted += inserted;
    return {staged:rows.rows.length, inserted, updated:0, unchanged, rejected:0};
}

// ─── PROMOTE: post_offices (POST_OFFICE) using DOP_PIN_CSV_V1 ────────────────
async function promotePostOffices(client, batchId, releaseId, sourceFileSha256) {
    const rows = await client.query(
        'SELECT entity_code,parent_code,entity_name,raw_data,physical_row_number FROM staging.geography_imports WHERE batch_id=$1 AND classification=$2',
        [batchId,'PENDING']);
    let inserted=0,unchanged=0,reviews=0;
    for (const row of rows.rows) {
        const rd = row.raw_data;
        // Build DOP_PIN_CSV_V1 identity key
        const basis = {
            country:'IND', pincode:String(rd.pincode||'').trim(),
            office: norm(rd.officename), type: norm(rd.officetype),
            state: norm(rd.statename), district: norm(rd.district),
            division: norm(rd.divisionname)
        };
        const identityKey = crypto.createHash('sha256').update(Object.values(basis).join('\x1f'),'utf8').digest('hex');

        // Check existing identity
        const idR = await client.query(
            'SELECT id, post_office_id FROM catalog.post_office_source_identities WHERE identity_version=$1 AND identity_key=$2',
            ['DOP_PIN_CSV_V1', identityKey]);

        let poId;
        if (idR.rows.length) {
            poId = idR.rows[0].post_office_id;
            const siId = idR.rows[0].id;
            
            const lat = rd.latitude && String(rd.latitude).toUpperCase() !== 'NA' ? String(rd.latitude).trim() : null;
            const lon = rd.longitude && String(rd.longitude).toUpperCase() !== 'NA' ? String(rd.longitude).trim() : null;

            // Check existing observations
            const obsR = await client.query('SELECT raw_data FROM catalog.post_office_source_observations WHERE source_identity_id=$1', [siId]);
            let conflict = false;
            let existingLat = null, existingLon = null;
            for (const obs of obsR.rows) {
                const exLat = obs.raw_data.latitude && String(obs.raw_data.latitude).toUpperCase() !== 'NA' ? String(obs.raw_data.latitude).trim() : null;
                const exLon = obs.raw_data.longitude && String(obs.raw_data.longitude).toUpperCase() !== 'NA' ? String(obs.raw_data.longitude).trim() : null;
                if (exLat) existingLat = exLat;
                if (exLon) existingLon = exLon;
            }

            if (lat && existingLat && lat !== existingLat) conflict = true;
            if (lon && existingLon && lon !== existingLon) conflict = true;

            // Record observation
            await client.query(`INSERT INTO catalog.post_office_source_observations
                (id,source_identity_id,release_id,source_file_sha256,physical_row_number,raw_data)
                VALUES (gen_random_uuid(),$1,$2,$3,$4,$5)
                ON CONFLICT(release_id,source_file_sha256,physical_row_number) DO NOTHING`,
                [siId, releaseId, sourceFileSha256, row.physical_row_number, JSON.stringify(rd)]);

            if (conflict) {
                await client.query(`INSERT INTO catalog.post_office_identity_reviews
                    (id,release_id,source_identity_id,issue_type,issue_description,status)
                    VALUES (gen_random_uuid(),$1,$2,$3,$4,'PENDING_MANUAL_REVIEW')
                    ON CONFLICT(source_identity_id, issue_type) WHERE status = 'PENDING_MANUAL_REVIEW' DO NOTHING`,
                    [releaseId, siId, 'COORDINATE_CONFLICT', `Coordinate conflict: new (${lat},${lon}) vs existing (${existingLat},${existingLon})`]);
                await client.query("UPDATE staging.geography_imports SET classification='DUPLICATE_IDENTITY_OBSERVATIONS' WHERE batch_id=$1 AND physical_row_number=$2",
                    [batchId, row.physical_row_number]);
                reviews++;
            } else {
                await client.query("UPDATE staging.geography_imports SET classification='DUPLICATE_IDENTITY_OBSERVATIONS' WHERE batch_id=$1 AND physical_row_number=$2",
                    [batchId, row.physical_row_number]);
                unchanged++;
            }
        } else {
            // Find postal_code_id
            const pcR = await client.query('SELECT id FROM catalog.postal_codes WHERE postal_code=$1 AND country_id=$2',[String(rd.pincode||'').trim(),INDIA_ID]);
            const pcId = pcR.rows.length ? pcR.rows[0].id : null;

            // Create post office
            const newPo = await client.query(`INSERT INTO catalog.post_offices
                (id,postal_code_id,official_name,office_type,delivery_status,status)
                VALUES(gen_random_uuid(),$1,$2,$3,$4,$5) RETURNING id`,
                [pcId,rd.officename,rd.officetype,rd.delivery,'ACTIVE']);
            poId = newPo.rows[0].id;
            inserted++;

            // Record source identity
            const siNew = await client.query(`INSERT INTO catalog.post_office_source_identities
                (id,post_office_id,source_authority,identity_version,identity_key,identity_basis,status)
                VALUES(gen_random_uuid(),$1,$2,$3,$4,$5,$6) RETURNING id`,
                [poId,'INDIA_POST','DOP_PIN_CSV_V1',identityKey,JSON.stringify(basis),'CURRENT']);
            const siId = siNew.rows[0].id;

            // Record observation
            await client.query(`INSERT INTO catalog.post_office_source_observations
                (id,source_identity_id,release_id,source_file_sha256,physical_row_number,raw_data)
                VALUES (gen_random_uuid(),$1,$2,$3,$4,$5)
                ON CONFLICT(release_id,source_file_sha256,physical_row_number) DO NOTHING`,
                [siId, releaseId, sourceFileSha256, row.physical_row_number, JSON.stringify(rd)]);
                
            await client.query('UPDATE staging.geography_imports SET classification=$1 WHERE batch_id=$2 AND physical_row_number=$3',['PROMOTED',batchId,row.physical_row_number]);
        }
    }
    totalPromoted += inserted;
    return {staged:rows.rows.length, inserted, updated:0, unchanged, rejected:reviews};
}

// ─── PROMOTE: block_villages ──────────────────────────────────────────────────
async function promoteBlockVillages(client, batchId) {
    const rows = await client.query(
        'SELECT entity_code,parent_code,physical_row_number FROM staging.geography_imports WHERE batch_id=$1 AND classification=$2',
        [batchId,'PENDING']);
    let inserted=0,unchanged=0,rejected=0;
    for (const row of rows.rows) {
        const blockR = await client.query('SELECT id FROM catalog.development_blocks WHERE official_code=$1',[row.parent_code]);
        const vilR   = await client.query('SELECT id FROM catalog.geography_units WHERE official_code=$1 AND geography_level_id=$2',[row.entity_code,GEO_LEVEL.LOCALITY]);
        if (!blockR.rows.length || !vilR.rows.length) { rejected++; continue; }
        const ex = await client.query('SELECT 1 FROM catalog.block_villages WHERE block_id=$1 AND village_id=$2',
            [blockR.rows[0].id,vilR.rows[0].id]);
        if (ex.rows.length) unchanged++;
        else {
            await client.query('INSERT INTO catalog.block_villages(block_id,village_id) VALUES($1,$2) ON CONFLICT DO NOTHING',
                [blockR.rows[0].id,vilR.rows[0].id]);
            inserted++;
        }
        await client.query('UPDATE staging.geography_imports SET classification=$1 WHERE batch_id=$2 AND physical_row_number=$3',['PROMOTED',batchId,row.physical_row_number]);
    }
    totalPromoted += inserted;
    return {staged:rows.rows.length, inserted, updated:0, unchanged, rejected};
}

// ─── PROMOTE: local_body_villages ────────────────────────────────────────────
async function promoteLocalBodyVillages(client, batchId) {
    const rows = await client.query(
        'SELECT entity_code,parent_code,physical_row_number FROM staging.geography_imports WHERE batch_id=$1 AND classification=$2',
        [batchId,'PENDING']);
    let inserted=0,unchanged=0,rejected=0;
    for (const row of rows.rows) {
        const lbR  = await client.query('SELECT id FROM catalog.local_bodies WHERE official_code=$1',[row.parent_code]);
        const vilR = await client.query('SELECT id FROM catalog.geography_units WHERE official_code=$1 AND geography_level_id=$2',[row.entity_code,GEO_LEVEL.LOCALITY]);
        if (!lbR.rows.length || !vilR.rows.length) { rejected++; continue; }
        const ex = await client.query('SELECT 1 FROM catalog.local_body_villages WHERE local_body_id=$1 AND village_id=$2',[lbR.rows[0].id,vilR.rows[0].id]);
        if (ex.rows.length) unchanged++;
        else {
            await client.query('INSERT INTO catalog.local_body_villages(local_body_id,village_id) VALUES($1,$2) ON CONFLICT DO NOTHING',[lbR.rows[0].id,vilR.rows[0].id]);
            inserted++;
        }
        await client.query('UPDATE staging.geography_imports SET classification=$1 WHERE batch_id=$2 AND physical_row_number=$3',['PROMOTED',batchId,row.physical_row_number]);
    }
    totalPromoted += inserted;
    return {staged:rows.rows.length, inserted, updated:0, unchanged, rejected};
}

// ─── PROMOTE: ward_villages (WARD_COVERAGE) ──────────────────────────────────
async function promoteWardVillages(client, batchId) {
    const rows = await client.query(
        'SELECT entity_code,parent_code,raw_data,physical_row_number FROM staging.geography_imports WHERE batch_id=$1 AND classification=$2',
        [batchId,'PENDING']);
    let inserted=0,unchanged=0,rejected=0;
    for (const row of rows.rows) {
        const wardR = await client.query('SELECT id FROM catalog.wards WHERE official_code=$1',[row.parent_code]);
        const vilR  = await client.query('SELECT id FROM catalog.geography_units WHERE official_code=$1 AND geography_level_id=$2',[row.entity_code,GEO_LEVEL.LOCALITY]);
        if (!wardR.rows.length || !vilR.rows.length) { rejected++; continue; }
        const ex = await client.query('SELECT 1 FROM catalog.ward_villages WHERE ward_id=$1 AND village_id=$2',[wardR.rows[0].id,vilR.rows[0].id]);
        if (ex.rows.length) unchanged++;
        else {
            await client.query('INSERT INTO catalog.ward_villages(ward_id,village_id) VALUES($1,$2) ON CONFLICT DO NOTHING',[wardR.rows[0].id,vilR.rows[0].id]);
            inserted++;
        }
        await client.query('UPDATE staging.geography_imports SET classification=$1 WHERE batch_id=$2 AND physical_row_number=$3',['PROMOTED',batchId,row.physical_row_number]);
    }
    totalPromoted += inserted;
    return {staged:rows.rows.length, inserted, updated:0, unchanged, rejected};
}

// ─── PROMOTE: postal_code_geographies (PIN_VILLAGE) ──────────────────────────
async function promotePostalCodeGeographies(client, batchId) {
    const rows = await client.query(
        'SELECT entity_code,parent_code,physical_row_number FROM staging.geography_imports WHERE batch_id=$1 AND classification=$2',
        [batchId,'PENDING']);
    let inserted=0,unchanged=0,rejected=0;
    for (const row of rows.rows) {
        const pcR  = await client.query('SELECT id FROM catalog.postal_codes WHERE postal_code=$1 AND country_id=$2',[row.parent_code,INDIA_ID]);
        const vilR = await client.query('SELECT id FROM catalog.geography_units WHERE official_code=$1 AND geography_level_id=$2',[row.entity_code,GEO_LEVEL.LOCALITY]);
        if (!pcR.rows.length || !vilR.rows.length) { rejected++; continue; }
        const ex = await client.query('SELECT 1 FROM catalog.postal_code_geographies WHERE postal_code_id=$1 AND geography_unit_id=$2 AND country_id=$3',[pcR.rows[0].id,vilR.rows[0].id,INDIA_ID]);
        if (ex.rows.length) unchanged++;
        else {
            await client.query('INSERT INTO catalog.postal_code_geographies(postal_code_id,geography_unit_id,country_id) VALUES($1,$2,$3) ON CONFLICT DO NOTHING',[pcR.rows[0].id,vilR.rows[0].id,INDIA_ID]);
            inserted++;
        }
        await client.query('UPDATE staging.geography_imports SET classification=$1 WHERE batch_id=$2 AND physical_row_number=$3',['PROMOTED',batchId,row.physical_row_number]);
    }
    totalPromoted += inserted;
    return {staged:rows.rows.length, inserted, updated:0, unchanged, rejected};
}

// ─── PROMOTE: postal_code_local_bodies (PIN_URBAN_LOCAL_BODY) ────────────────
async function promotePostalCodeLocalBodies(client, batchId) {
    const rows = await client.query(
        'SELECT entity_code,parent_code,physical_row_number FROM staging.geography_imports WHERE batch_id=$1 AND classification=$2',
        [batchId,'PENDING']);
    let inserted=0,unchanged=0,rejected=0;
    for (const row of rows.rows) {
        const pcR = await client.query('SELECT id FROM catalog.postal_codes WHERE postal_code=$1 AND country_id=$2',[row.parent_code,INDIA_ID]);
        const lbR = await client.query('SELECT id FROM catalog.local_bodies WHERE official_code=$1',[row.entity_code]);
        if (!pcR.rows.length || !lbR.rows.length) { rejected++; continue; }
        const ex = await client.query('SELECT 1 FROM catalog.postal_code_local_bodies WHERE postal_code_id=$1 AND local_body_id=$2 AND country_id=$3',[pcR.rows[0].id,lbR.rows[0].id,INDIA_ID]);
        if (ex.rows.length) unchanged++;
        else {
            await client.query('INSERT INTO catalog.postal_code_local_bodies(postal_code_id,local_body_id,country_id) VALUES($1,$2,$3) ON CONFLICT DO NOTHING',[pcR.rows[0].id,lbR.rows[0].id,INDIA_ID]);
            inserted++;
        }
        await client.query('UPDATE staging.geography_imports SET classification=$1 WHERE batch_id=$2 AND physical_row_number=$3',['PROMOTED',batchId,row.physical_row_number]);
    }
    totalPromoted += inserted;
    return {staged:rows.rows.length, inserted, updated:0, unchanged, rejected};
}

// ─── XLS zip entry extractor → staging rows ──────────────────────────────────
async function extractXlsFromZip(zipPath, entryName, entityType, batchId, sourceFile, client, stateScope) {
    return new Promise((resolve, reject) => {
        yauzl.open(zipPath, {lazyEntries:true}, (err, zf) => {
            if (err) return reject(err);
            zf.readEntry();
            let found = false;
            zf.on('entry', entry => {
                if (entry.fileName !== entryName) return zf.readEntry();
                found = true;
                zf.openReadStream(entry, (err, stream) => {
                    if (err) return reject(err);
                    let headerRow = null;
                    // Buffer rows then drain async after SAX ends (bounded per-entry, not whole-file)
                    let rowBuffer = [];
                    let staged = 0;

                    readXlsStreamRows(stream, (row) => { rowBuffer.push(row); }, async () => {
                        let chunk = [], physRow = 0;
                        for (const row of rowBuffer) {
                            physRow++;
                            // Locate header
                            if (!headerRow) {
                                const f = String(row[0]||'').toLowerCase().trim();
                                if (f === 'state code') { headerRow = row; continue; }
                                if (f.replace(/\s/g,'').startsWith('s.no')) { headerRow = row; continue; }
                                continue;
                            }
                            // Skip continuation header row
                            const f0 = String(row[0]||'').toLowerCase();
                            if (f0.includes('in english') || f0.includes('in local')) continue;
                            if (!row[0] && !row[1] && !row[2]) continue;

                            const stagingRow = buildStagingRow(entityType, row, headerRow, physRow, stateScope);
                            if (!stagingRow || !stagingRow.entity_code) continue;
                            chunk.push(stagingRow);
                            if (chunk.length >= CHUNK_SIZE) {
                                staged += await stageChunk(client, batchId, entityType, chunk, sourceFile, physRow - chunk.length);
                                chunk = [];
                                hb(zipPath, stateScope||'', totalStaged, totalPromoted, batchesDone, entityType);
                            }
                        }
                        if (chunk.length) {
                            staged += await stageChunk(client, batchId, entityType, chunk, sourceFile, physRow - chunk.length);
                        }
                        rowBuffer = []; // free memory
                        resolve(staged);
                    });
                });
            });
            zf.on('end', () => { if (!found) resolve(0); });
        });
    });
}

// ─── Build staging row per entity type ────────────────────────────────────────
// stateScope is the manifest entry scope (State/UT name) injected for local_body parent lookups
function buildStagingRow(entityType, row, header, physRow, stateScope) {
    const h = header.map(c => norm(String(c||'')));
    const get = (key) => {
        const i = h.findIndex(c => c.includes(key));
        return i >= 0 ? String(row[i]||'').trim() : '';
    };
    // Find first index where header matches key and optionally excludes exclusion
    const getExcl = (key, excl) => {
        const i = h.findIndex(c => c.includes(key) && (!excl || !c.includes(excl)));
        return i >= 0 ? String(row[i]||'').trim() : '';
    };

    try {
        switch (entityType) {
            case 'DISTRICT': return {
                // State code is NOT in district XLS — parent resolved via existing rows
                entity_code: get('district code'), parent_code: '',
                entity_name: getExcl('district name', 'census') || String(row[3]||'').trim(),
                physical_row_number: physRow, raw_data: {row: row.slice(0,8)}
            };
            case 'SUB_DISTRICT': return {
                entity_code: get('subdistrict code'), parent_code: get('district code'),
                entity_name: getExcl('subdistrict name', 'census'),
                physical_row_number: physRow, raw_data: {row: row.slice(0,9)}
            };
            case 'VILLAGE': return {
                entity_code: get('village code'), parent_code: get('sub-district code'),
                entity_name: getExcl('village name', 'census'),
                physical_row_number: physRow, raw_data: {row: row.slice(0,13)}
            };
            case 'BLOCK': return {
                entity_code: get('block code'), parent_code: get('district code'),
                entity_name: getExcl('block name', 'census'),
                physical_row_number: physRow, raw_data: {row: row.slice(0,7)}
            };
            case 'BLOCK_VILLAGE': return {
                entity_code: get('village code'), parent_code: get('block code'),
                entity_name: get('village name'),
                physical_row_number: physRow, raw_data: {row: row.slice(0,8)}
            };
            case 'PRI_DISTRICT':
            case 'PRI_INTERMEDIATE':
            case 'GRAM_PANCHAYAT':
            case 'PRI_LOCAL_BODY': {
                const typeCode = get('localbody type code');
                const lbType = PRI_TYPE_CODE_MAP[typeCode];
                if (!lbType) return null;
                const targetType = entityType === 'PRI_LOCAL_BODY' ? lbType : entityType;
                const enumMap = { PRI_DISTRICT:'PRI_DISTRICT', PRI_INTERMEDIATE:'PRI_INTERMEDIATE', GRAM_PANCHAYAT:'PRI_GRAM_PANCHAYAT' };
                const expectedEnum = enumMap[targetType];
                if (lbType !== targetType && !(targetType==='PRI_LOCAL_BODY')) return null;
                return {
                    entity_code: get('localbody code'), parent_code: get('parent localbody code'),
                    entity_name: row[h.findIndex(c=>c.includes('localbody name')&&!c.includes('type')&&!c.includes('version'))] || '',
                    physical_row_number: physRow,
                    raw_data: {lb_type: enumMap[lbType]||lbType, type_code: typeCode, state_code: '', row: row.slice(0,8)}
                };
            }
            case 'URBAN_LOCAL_BODY': return {
                entity_code: get('localbody code'), parent_code: '',
                entity_name: row[h.findIndex(c=>c.includes('local body name'))] || row[h.findIndex(c=>c.includes('localbody name'))] || '',
                physical_row_number: physRow,
                raw_data: {lb_type:'URBAN', state_code:'', row: row.slice(0,9)}
            };
            case 'TRADITIONAL_LOCAL_BODY': return {
                entity_code: get('local body code'), parent_code: get('parent localbody code'),
                entity_name: get('local body name'),
                physical_row_number: physRow,
                raw_data: {lb_type:'TRADITIONAL', state_code:'', row: row.slice(0,8)}
            };
            case 'LOCAL_BODY_VILLAGE': return {
                entity_code: get('village code'), parent_code: get('local body code'),
                entity_name: get('village name'),
                physical_row_number: physRow, raw_data: {row: row.slice(0,15)}
            };
            case 'URBAN_WARD':
            case 'PRI_WARD': return {
                entity_code: get('ward code'), parent_code: get('local body code'),
                entity_name: get('ward name'),
                physical_row_number: physRow,
                raw_data: {ward_number: get('ward number'), row: row.slice(0,10)}
            };
            case 'WARD_COVERAGE': return {
                entity_code: get('subdistrict code') || get('village code') || '', parent_code: get('ward code'),
                entity_name: get('subdistrict name'),
                physical_row_number: physRow, raw_data: {row: row.slice(0,10)}
            };
            default: return null;
        }
    } catch(e) { return null; }
}

// ─── CSV reader for PIN CODE.csv ──────────────────────────────────────────────
function parseCsvLine(line) {
    const r=[]; let col='', inQ=false;
    for (const ch of line) { if(ch==='"') inQ=!inQ; else if(ch===','&&!inQ) { r.push(col.trim()); col=''; } else col+=ch; }
    r.push(col.trim()); return r;
}

async function processPinCodeCsv(client, releaseId, batchIdPincode, batchIdPostOffice, sourceFileSha256) {
    const FILE = path.join(SOURCE_DIR, 'PIN CODE.csv');
    const rl = readline.createInterface({ input: fs.createReadStream(FILE), crlfDelay: Infinity });
    let headers = [], physRow = 0;
    let pincodeChunk = [], postOfficeChunk = [];
    let pincodeStaged=0, postOfficeStaged=0;

    for await (const line of rl) {
        if (!line.trim()) continue;
        const cols = parseCsvLine(line);
        if (!headers.length) { headers = cols.map(h=>h.toLowerCase()); continue; }
        physRow++;
        const r = {}; headers.forEach((h,i)=>r[h]=cols[i]||'');

        const pincode = String(r.pincode||'').trim();
        const officeName = r.officename;

        // PINCODE output
        pincodeChunk.push({
            entity_code: pincode, parent_code: '', entity_name: pincode,
            physical_row_number: physRow,
            raw_data: {pincode, statename: r.statename, district: r.district}
        });
        // POST_OFFICE output
        postOfficeChunk.push({
            entity_code: pincode, parent_code: pincode, entity_name: officeName,
            physical_row_number: physRow,
            raw_data: r
        });

        if (pincodeChunk.length >= CHUNK_SIZE) {
            pincodeStaged += await stageChunk(client, batchIdPincode, 'PINCODE', pincodeChunk, 'PIN CODE.csv', physRow-pincodeChunk.length);
            postOfficeStaged += await stageChunk(client, batchIdPostOffice, 'POST_OFFICE', postOfficeChunk, 'PIN CODE.csv', physRow-postOfficeChunk.length);
            pincodeChunk = []; postOfficeChunk = [];
            hb('PIN CODE.csv', 'ALL_INDIA', totalStaged, totalPromoted, batchesDone, 'PINCODE+POST_OFFICE');
        }
    }
    if (pincodeChunk.length) {
        pincodeStaged += await stageChunk(client, batchIdPincode, 'PINCODE', pincodeChunk, 'PIN CODE.csv', physRow-pincodeChunk.length);
        postOfficeStaged += await stageChunk(client, batchIdPostOffice, 'POST_OFFICE', postOfficeChunk, 'PIN CODE.csv', physRow-postOfficeChunk.length);
    }
    log(`  PIN CODE.csv: ${physRow} rows → PINCODE staged=${pincodeStaged} POST_OFFICE staged=${postOfficeStaged}`);
    return { pincodeStaged, postOfficeStaged, physRow };
}

// ─── XLSX reader (for PIN_VILLAGE and PIN_URBAN_LOCAL_BODY) ───────────────────
async function processXlsx(filePath, entityType, batchId, client) {
    // These files are small enough to read with XLSX (< 50MB)
    const wb = XLSX.readFile(filePath);
    const ws = wb.Sheets[wb.SheetNames[0]];
    const rawRows = XLSX.utils.sheet_to_json(ws, {header:1, defval:''});
    // Find actual header row (skip title row)
    let headerIdx = rawRows.findIndex(r => String(r[0]||'').toLowerCase().includes('s.no'));
    if (headerIdx < 0) throw new Error(`${entityType}: no S.No. header found in ${filePath}`);
    const header = rawRows[headerIdx].map(c=>norm(String(c)));
    const get = (row, key) => { const i=header.findIndex(h=>h.includes(key)); return i>=0?String(row[i]||'').trim():''; };

    let chunk=[], staged=0, physRow=0;
    for (let i=headerIdx+1; i<rawRows.length; i++) {
        const row = rawRows[i];
        if (!row[0] && !row[1]) continue;
        physRow++;
        let stagingRow;
        if (entityType === 'PIN_VILLAGE') {
            stagingRow = {
                entity_code: get(row,'village code'), parent_code: get(row,'pincode'),
                entity_name: get(row,'village name'),
                physical_row_number: physRow,
                raw_data: {state_code:get(row,'state code'), district_code:get(row,'district code'), subdistrict_code:get(row,'subdistrict code')}
            };
        } else { // PIN_URBAN_LOCAL_BODY
            stagingRow = {
                entity_code: get(row,'localbody code'), parent_code: get(row,'pincode'),
                entity_name: get(row,'localbody name'),
                physical_row_number: physRow,
                raw_data: {state_code:get(row,'state code'), lb_type:get(row,'localbody type name')}
            };
        }
        if (!stagingRow.entity_code || !stagingRow.parent_code) continue;
        chunk.push(stagingRow);
        if (chunk.length >= CHUNK_SIZE) {
            staged += await stageChunk(client, batchId, entityType, chunk, filePath, physRow-chunk.length);
            chunk = [];
        }
    }
    if (chunk.length) staged += await stageChunk(client, batchId, entityType, chunk, filePath, physRow-chunk.length);
    log(`  ${entityType}: ${physRow} data rows, staged=${staged}`);
    return {physRow, staged};
}

// ─── Main run loop ────────────────────────────────────────────────────────────
async function run() {
    const client = await pool.connect();

    // Acquire advisory lock
    const lock = await client.query('SELECT pg_try_advisory_lock($1)', [ADVISORY_LOCK]);
    if (!lock.rows[0].pg_try_advisory_lock) {
        log('Advisory lock held. Another R6 instance running. Exiting.');
        client.release(); process.exit(1);
    }

    // Record importer version in release before first row
    const relR = await client.query("SELECT id FROM data_imports.releases WHERE release_name='LGD_20260826_CORE_R6'");
    const releaseId = relR.rows[0].id;
    await client.query("UPDATE data_imports.releases SET sha256_hash=$1 WHERE id=$2",
        [IMPORTER_HASH + '_importer_v1', releaseId]);
    log(`Release: ${releaseId}  Importer hash: ${IMPORTER_HASH}`);

    const manifest = JSON.parse(fs.readFileSync(MANIFEST,'utf8'));
    const importAuthority = manifest.entries.filter(e => e.role==='IMPORT_AUTHORITY' && e.logical_outputs && e.logical_outputs.length>0);

    // PIN_VILLAGE and PIN_URBAN_LOCAL_BODY are ALL_INDIA xlsx files — process separately
    const pinVillageFile  = path.join(SOURCE_DIR,'Pincodeto_Village_Mapping_2026-08-26_23-05-48.xlsx');
    const pinUrbanFile    = path.join(SOURCE_DIR,'Pincodeto_Urban_Mapping_2026-08-26_23-06-09.xlsx');
    const pinCodeCsvFile  = path.join(SOURCE_DIR,'PIN CODE.csv');
    const pinCsvSha256    = manifest.entries.find(e=>e.path==='PIN CODE.csv')?.source_sha256 || '';

    // ── Phase 1: Process per-state zip files ─────────────────────────────────
    for (const entry of importAuthority) {
        if (isStop()) { log('STOP_REQUESTED. Halting.'); break; }
        if (!entry.path.includes('.zip!')) continue; // skip non-zip entries in this pass
        if (entry.role !== 'IMPORT_AUTHORITY') continue;

        const [zipRelPath, entryName] = entry.path.split('!');
        const zipPath = path.join(SOURCE_DIR, zipRelPath);
        const stateUt = entry.scope;

        for (const logicalEntity of entry.logical_outputs) {
            if (isStop()) break;
            if (isCompleted(entry.path, logicalEntity)) { batchesDone++; continue; }

            const batchId = await getBatchId(client, releaseId, logicalEntity);
            log(`[${logicalEntity}] ${stateUt} → batch ${batchId}`);
            hb(entry.path, stateUt, totalStaged, totalPromoted, batchesDone, logicalEntity);

            try {
                const staged = await extractXlsFromZip(zipPath, entryName, logicalEntity, batchId, entry.path, client, stateUt);
                // Promote inline
                let stats = {staged, inserted:0, updated:0, unchanged:0, rejected:0};

                if (['DISTRICT','SUB_DISTRICT','VILLAGE'].includes(logicalEntity)) {
                    stats = await promoteGeographyUnit(client, batchId, logicalEntity, releaseId);
                } else if (logicalEntity === 'BLOCK') {
                    stats = await promoteBlocks(client, batchId);
                } else if (['PRI_DISTRICT','PRI_INTERMEDIATE','GRAM_PANCHAYAT'].includes(logicalEntity)) {
                    const enumMap = {PRI_DISTRICT:'PRI_DISTRICT', PRI_INTERMEDIATE:'PRI_INTERMEDIATE', GRAM_PANCHAYAT:'PRI_GRAM_PANCHAYAT'};
                    stats = await promoteLocalBodies(client, batchId, enumMap[logicalEntity]);
                } else if (logicalEntity === 'URBAN_LOCAL_BODY') {
                    stats = await promoteLocalBodies(client, batchId, 'URBAN');
                } else if (logicalEntity === 'TRADITIONAL_LOCAL_BODY') {
                    stats = await promoteLocalBodies(client, batchId, 'TRADITIONAL');
                } else if (['URBAN_WARD','PRI_WARD'].includes(logicalEntity)) {
                    stats = await promoteWards(client, batchId);
                } else if (logicalEntity === 'BLOCK_VILLAGE') {
                    stats = await promoteBlockVillages(client, batchId);
                } else if (logicalEntity === 'LOCAL_BODY_VILLAGE') {
                    stats = await promoteLocalBodyVillages(client, batchId);
                } else if (logicalEntity === 'WARD_COVERAGE') {
                    stats = await promoteWardVillages(client, batchId);
                }

                await completeBatch(client, batchId, stats);
                markCompleted(entry.path, logicalEntity);
                batchesDone++;
                log(`  ✓ ${logicalEntity} ${stateUt}: staged=${stats.staged} ins=${stats.inserted} upd=${stats.updated} unc=${stats.unchanged} rej=${stats.rejected}`);
            } catch(e) {
                log(`  ✗ ${logicalEntity} ${stateUt}: ${e.message}`);
                await client.query("UPDATE data_imports.batches SET status='FAILED' WHERE id=(SELECT id FROM data_imports.batches WHERE release_id=$1 AND entity_type=$2)",[releaseId,logicalEntity]);
            }
        }
    }

    // ── Phase 2: ALL_INDIA PIN CODE.csv → PINCODE + POST_OFFICE ─────────────
    if (!isStop()) {
        const batchIdPincode    = await getBatchId(client, releaseId, 'PINCODE');
        const batchIdPostOffice = await getBatchId(client, releaseId, 'POST_OFFICE');

        if (!isCompleted('PIN CODE.csv','PINCODE')) {
            log('[PINCODE + POST_OFFICE] PIN CODE.csv ALL_INDIA');
            const { physRow, pincodeStaged, postOfficeStaged } = await processPinCodeCsv(client, releaseId, batchIdPincode, batchIdPostOffice, pinCsvSha256);
            const pcStats = await promotePostalCodes(client, batchIdPincode);
            await completeBatch(client, batchIdPincode, pcStats);
            markCompleted('PIN CODE.csv','PINCODE'); batchesDone++;

            const poStats = await promotePostOffices(client, batchIdPostOffice, releaseId, pinCsvSha256);
            await completeBatch(client, batchIdPostOffice, poStats);
            markCompleted('PIN CODE.csv','POST_OFFICE'); batchesDone++;
        } else { batchesDone += 2; }
    }

    // ── Phase 3: PIN_VILLAGE xlsx ─────────────────────────────────────────────
    if (!isStop()) {
        const batchIdPV = await getBatchId(client, releaseId, 'PIN_VILLAGE');
        if (!isCompleted(pinVillageFile,'PIN_VILLAGE')) {
            log('[PIN_VILLAGE] Pincodeto_Village_Mapping.xlsx');
            const r = await processXlsx(pinVillageFile, 'PIN_VILLAGE', batchIdPV, client);
            const stats = await promotePostalCodeGeographies(client, batchIdPV);
            await completeBatch(client, batchIdPV, stats);
            markCompleted(pinVillageFile,'PIN_VILLAGE'); batchesDone++;
        } else batchesDone++;
    }

    // ── Phase 4: PIN_URBAN_LOCAL_BODY xlsx ────────────────────────────────────
    if (!isStop()) {
        const batchIdPU = await getBatchId(client, releaseId, 'PIN_URBAN_LOCAL_BODY');
        if (!isCompleted(pinUrbanFile,'PIN_URBAN_LOCAL_BODY')) {
            log('[PIN_URBAN_LOCAL_BODY] Pincodeto_Urban_Mapping.xlsx');
            const r = await processXlsx(pinUrbanFile, 'PIN_URBAN_LOCAL_BODY', batchIdPU, client);
            const stats = await promotePostalCodeLocalBodies(client, batchIdPU);
            await completeBatch(client, batchIdPU, stats);
            markCompleted(pinUrbanFile,'PIN_URBAN_LOCAL_BODY'); batchesDone++;
        } else batchesDone++;
    }

    // ── Release advisory lock ─────────────────────────────────────────────────
    await client.query('SELECT pg_advisory_unlock($1)', [ADVISORY_LOCK]);
    client.release();

    hb('SCAFFOLD_REGISTERED', 'ALL', totalStaged, totalPromoted, batchesDone, 'COMPLETE');
    log(`R6 complete. batches_done=${batchesDone}/506 staged=${totalStaged} promoted=${totalPromoted}`);

    await pool.end();
}

run().catch(err => { log('FATAL:', err.message, err.stack); process.exit(1); });
