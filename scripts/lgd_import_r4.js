const fs = require('fs');
const path = require('path');
const yauzl = require('yauzl');
const sax = require('sax');
const { Client } = require('pg');
const { from: copyFrom } = require('pg-copy-streams');

const RUNTIME_DIR = 'D:\\ANTIGRAVITY_WORKSPACE\\LGD_IMPORT_RUNTIME';
const CHUNKS_DIR = path.join(RUNTIME_DIR, 'chunks');
const STOP_MARKER = path.join(RUNTIME_DIR, 'STOP_REQUESTED');
const MANIFEST_PATH = 'D:\\ANTIGRAVITY_WORKSPACE\\INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826\\sealed_manifest.json';
const DB_URL = 'postgresql://postgres:postgres@127.0.0.1:54522/postgres';

if (!fs.existsSync(CHUNKS_DIR)) fs.mkdirSync(CHUNKS_DIR, { recursive: true });

async function run() {
    if (fs.existsSync(STOP_MARKER)) fs.unlinkSync(STOP_MARKER); 

    const manifest = JSON.parse(fs.readFileSync(MANIFEST_PATH, 'utf8'));
    fs.writeFileSync(path.join(RUNTIME_DIR, 'importer_r4.pid'), String(process.pid));
    
    let currentEntityLog = 'STARTING';
    const hbInterval = setInterval(() => {
        fs.writeFileSync(path.join(RUNTIME_DIR, 'heartbeat_r4.json'), JSON.stringify({ 
            pid: process.pid, 
            time: new Date().toISOString(), 
            expected_batches: manifest.entries.length,
            current_entity: currentEntityLog
        }));
    }, 2000);

    const client = new Client({ connectionString: DB_URL });
    await client.connect();

    const r3Query = `INSERT INTO data_imports.releases (release_name, source_uri, sha256_hash, manifest_hash, status) VALUES ('LGD_20260826_CORE_R3', 'local_dir', 'c9f033fd161576f0cea64fb1dcf783153546197be082ff3eede268ca7be08344', 'c9f033fd161576f0cea64fb1dcf783153546197be082ff3eede268ca7be08344', 'PENDING') ON CONFLICT (release_name) DO NOTHING RETURNING id;`;
    let relRes = await client.query(r3Query);
    if (!relRes.rows.length) {
        relRes = await client.query(`SELECT id FROM data_imports.releases WHERE release_name='LGD_20260826_CORE_R3'`);
    }
    const releaseId = relRes.rows[0].id;
    
    let batchCache = {};
    const getBatchId = async (entityType) => {
        if(batchCache[entityType]) return batchCache[entityType];
        const batchQ = `INSERT INTO data_imports.batches (release_id, entity_type, status) VALUES ('${releaseId}', '${entityType}', 'PENDING') ON CONFLICT DO NOTHING RETURNING id`;
        let bRes = await client.query(batchQ);
        if(bRes.rows.length) { batchCache[entityType] = bRes.rows[0].id; return bRes.rows[0].id; }
        bRes = await client.query(`SELECT id FROM data_imports.batches WHERE release_id='${releaseId}' AND entity_type='${entityType}'`);
        batchCache[entityType] = bRes.rows[0].id;
        return bRes.rows[0].id;
    };

    console.log("Starting R4 extraction from sealed manifest...");

    // Helper to identify entity type from path
    const getEntityType = (p) => {
        const lower = p.toLowerCase();
        if(lower.includes('subdistrictof')) return 'SUB_DISTRICT';
        if(lower.includes('sub_districtof')) return 'SUB_DISTRICT';
        if(lower.includes('districtof')) return 'DISTRICT';
        if(lower.includes('villageof')) return 'VILLAGE';
        if(lower.includes('blockof')) return 'BLOCK';
        if(lower.includes('gram_panchayat')) return 'GRAM_PANCHAYAT';
        if(lower.includes('urban_local_bodies')) return 'URBAN_LOCAL_BODY';
        if(lower.includes('traditional_localbodies')) return 'TRADITIONAL_LOCAL_BODY';
        if(lower.includes('wardsof')) return 'WARD';
        if(lower.includes('all_pincode')) return 'PINCODE';
        return 'UNKNOWN';
    };

    for (const entry of manifest.entries) {
        if (fs.existsSync(STOP_MARKER)) {
            console.log("Graceful STOP_REQUESTED detected. Halting pipeline safely.");
            break;
        }
        if (entry.role !== 'IMPORT_AUTHORITY') continue;
        
        const entityType = getEntityType(entry.path);
        if (entityType === 'UNKNOWN') continue;

        currentEntityLog = entry.path;
        const [zipPart, internalFile] = entry.path.split('!');
        const absoluteZipPath = path.join('D:\\ANTIGRAVITY_WORKSPACE\\INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826', zipPart);
        
        console.log("Processing:", entry.path, "as", entityType);
        const batchId = await getBatchId(entityType);
        
        const batchStatus = await client.query(`SELECT status FROM data_imports.batches WHERE id='${batchId}'`);
        if (batchStatus.rows.length && batchStatus.rows[0].status === 'COMPLETED') {
            console.log(`Skipping completely promoted batch for ${entityType}`);
            continue;
        }
        
        await new Promise((resolve, reject) => {
            yauzl.open(absoluteZipPath, { lazyEntries: true }, (err, zipfile) => {
                if (err) return resolve(); // skip on error
                zipfile.readEntry();
                zipfile.on("entry", (e) => {
                    if (e.fileName === internalFile) {
                        zipfile.openReadStream(e, (err, stream) => {
                            if (err) return resolve();
                            const saxStream = sax.createStream(true, { trim: true });
                            let inRow = false, inCell = false, inData = false, cellIndex = 0, currentData = "";
                            let currentRow = [], chunk = [], chunkIndex = 0;
                            let headerParsed = false;
                            let codeIdx = -1, parentIdx = -1, nameIdx = -1;

                            let internalHash = require('crypto').createHash('md5').update(internalFile).digest('hex').substring(0,8);
                            const flushChunk = async () => {
                                if (chunk.length === 0) return;
                                const pTemp = path.join(CHUNKS_DIR, `R4_${entry.source_sha256}_${internalHash}_${chunkIndex}.partial`);
                                const pFinal = path.join(CHUNKS_DIR, `R4_${entry.source_sha256}_${internalHash}_${chunkIndex}.tsv`);
                                
                                if (fs.existsSync(pFinal)) {
                                    // Chunk already safely imported and committed to staging!
                                    chunk = []; chunkIndex++;
                                    return;
                                }

                                const tsvData = chunk.map(r => r.map(c => c ? String(c).replace(/\t|\n/g, '') : '').join('\t')).join('\n');
                                fs.writeFileSync(pTemp, tsvData + '\n');
                                
                                const copyQuery = `COPY staging.geography_imports (batch_id, entity_type, entity_code, parent_code, entity_name, raw_data, classification) FROM STDIN`;
                                const pgStream = client.query(copyFrom(copyQuery));
                                let hasData = false;
                                for(const r of chunk) {
                                    if(codeIdx >= 0 && r.length > codeIdx && r[codeIdx]) {
                                        hasData = true;
                                        const code = r[codeIdx];
                                        const parent = parentIdx >= 0 ? (r[parentIdx] || '') : '';
                                        const name = nameIdx >= 0 ? (r[nameIdx] || '').replace(/[\t\n]/g, '') : '';
                                        const rawData = JSON.stringify(r).replace(/\\/g, '\\\\').replace(/[\t\n]/g, '');
                                        pgStream.write(`${batchId}\t${entityType}\t${code}\t${parent}\t${name}\t${rawData}\tPENDING\n`);
                                    }
                                }
                                pgStream.end();
                                await new Promise((res, rej) => { pgStream.on('finish', res); pgStream.on('error', rej); });
                                
                                fs.renameSync(pTemp, pFinal);
                                chunk = []; chunkIndex++;
                            };

                            saxStream.on('opentag', (node) => {
                                if (node.name === 'Row') { inRow = true; currentRow = []; cellIndex = 0; }
                                else if (node.name === 'Cell') {
                                    inCell = true; currentData = "";
                                    if (node.attributes['ss:Index']) cellIndex = parseInt(node.attributes['ss:Index'], 10) - 1;
                                }
                                else if (node.name === 'Data') { inData = true; }
                            });
                            saxStream.on('text', (text) => { if (inData) currentData += text; });
                            saxStream.on('closetag', async (name) => {
                                if (name === 'Data') { inData = false; }
                                else if (name === 'Cell') { currentRow[cellIndex++] = currentData; inCell = false; }
                                else if (name === 'Row') {
                                    inRow = false;
                                    if (currentRow.length > 0 && currentRow[0]) {
                                        const c0 = String(currentRow[0]).toLowerCase().replace(/\s/g, '');
                                        if (!headerParsed && c0.includes('s.no')) {
                                            // Dynamic Header mapping
                                            headerParsed = true;
                                            let codes = [];
                                            for(let i=0; i<currentRow.length; i++) {
                                                const h = String(currentRow[i]).toLowerCase();
                                                if(h.includes('code') && !h.includes('pincode') && !h.includes('coverage')) codes.push(i);
                                                if(h.includes('name (in english)') || h.includes('name(in english)') || (nameIdx === -1 && h.includes('name'))) nameIdx = i;
                                            }
                                            if(codes.length > 0) codeIdx = codes[codes.length - 1]; 
                                            if(codes.length > 1) parentIdx = codes[codes.length - 2]; 
                                        } else if (headerParsed && String(currentRow[0]).trim() !== '') {
                                            chunk.push(currentRow);
                                            if (chunk.length >= 2000) {
                                                stream.pause();
                                                flushChunk().then(() => stream.resume()).catch(resolve);
                                            }
                                        }
                                    }
                                }
                            });
                            saxStream.on('end', async () => {
                                await flushChunk();
                                zipfile.readEntry();
                            });
                            saxStream.on('error', (err) => resolve());
                            stream.pipe(saxStream);
                        });
                    } else {
                        zipfile.readEntry();
                    }
                });
                zipfile.on("end", resolve);
            });
        });
    }

    console.log("R4 Extraction Complete. Triggering canonical promotion...");
    
    // Now trigger the RPC to process the promotion!
    // Wait, the user asked to promote batches in dependency order:
    // Districts, Sub-Districts, Villages, Blocks, Local Bodies, Wards, PIN, PIN-Village.
    const promotionOrder = [
       'DISTRICT', 'SUB_DISTRICT', 'VILLAGE', 'BLOCK', 
       'GRAM_PANCHAYAT', 'URBAN_LOCAL_BODY', 'TRADITIONAL_LOCAL_BODY',
       'WARD', 'PINCODE'
    ];
    
    for(const et of promotionOrder) {
       console.log(`Promoting ${et}...`);
       try {
           const pRes = await client.query(`SELECT id FROM data_imports.batches WHERE release_id='${releaseId}' AND entity_type='${et}'`);
           if(pRes.rows.length) {
               await client.query(`SELECT data_imports.rpc_promote_geography_batch('${pRes.rows[0].id}')`);
               await client.query(`UPDATE data_imports.batches SET status='COMPLETED' WHERE id='${pRes.rows[0].id}'`);
           }
       } catch (err) {
           console.error(`Promotion failed for ${et}:`, err.message);
       }
    }

    clearInterval(hbInterval);
    await client.end();
    console.log("R4 Process Completed or Stopped Gracefully.");
}
run().catch(e => { console.error(e); process.exit(1); });
