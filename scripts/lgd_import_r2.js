const fs = require('fs');
const path = require('path');
const yauzl = require('yauzl');
const sax = require('sax');
const { Client } = require('pg');
const crypto = require('crypto');
const { from: copyFrom } = require('pg-copy-streams');

const SOURCE_DIR = 'D:\\ANTIGRAVITY_WORKSPACE\\INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826';
const RUNTIME_DIR = 'D:\\ANTIGRAVITY_WORKSPACE\\LGD_IMPORT_RUNTIME';
const CHUNKS_DIR = path.join(RUNTIME_DIR, 'chunks');
const DB_URL = 'postgresql://postgres:postgres@127.0.0.1:54522/postgres';

function md5(str) { return crypto.createHash('md5').update(String(str)).digest('hex'); }
function formatUUID(hex) { return hex.slice(0,8) + '-' + hex.slice(8,12) + '-' + hex.slice(12,16) + '-' + hex.slice(16,20) + '-' + hex.slice(20); }

async function run() {
    if (!fs.existsSync(RUNTIME_DIR)) fs.mkdirSync(RUNTIME_DIR, { recursive: true });
    if (!fs.existsSync(CHUNKS_DIR)) fs.mkdirSync(CHUNKS_DIR, { recursive: true });
    
    fs.writeFileSync(path.join(RUNTIME_DIR, 'importer.pid'), String(process.pid));
    
    const hbInterval = setInterval(() => {
        fs.writeFileSync(path.join(RUNTIME_DIR, 'heartbeat.json'), JSON.stringify({ pid: process.pid, time: new Date().toISOString() }));
    }, 1000);

    const client = new Client({ connectionString: DB_URL });
    await client.connect();

    const relRes = await client.query(`INSERT INTO data_imports.releases (release_name, source_uri, sha256_hash) VALUES ('LGD_20260826_CORE_R2', 'local_dir', 'sha256_core_r2') ON CONFLICT DO NOTHING RETURNING id`);
    const releaseId = relRes.rows.length ? relRes.rows[0].id : (await client.query(`SELECT id FROM data_imports.releases WHERE release_name='LGD_20260826_CORE_R2'`)).rows[0].id;
    
    const batchQ = `INSERT INTO data_imports.batches (release_id, entity_type, status) VALUES ('${releaseId}', 'VILLAGE_CHUNK_TEST_R2', 'PENDING') ON CONFLICT DO NOTHING RETURNING id`;
    let batchRes = await client.query(batchQ);
    let batchId = batchRes.rows.length ? batchRes.rows[0].id : (await client.query(`SELECT id FROM data_imports.batches WHERE release_id='${releaseId}' AND entity_type='VILLAGE_CHUNK_TEST_R2'`)).rows[0].id;

    console.log("Starting generalized streaming extraction...");
    
    const dirs = fs.readdirSync(SOURCE_DIR);
    for (const d of dirs) {
        const fullDir = path.join(SOURCE_DIR, d);
        if (!fs.statSync(fullDir).isDirectory()) continue;
        const zips = fs.readdirSync(fullDir).filter(f => f.endsWith('.zip'));
        if (zips.length === 0) continue;
        
        const zipPath = path.join(fullDir, zips[0]);
        console.log("Processing ZIP:", zipPath);
        
        await new Promise((resolve, reject) => {
            yauzl.open(zipPath, { lazyEntries: true }, (err, zipfile) => {
                if (err) return reject(err);
                zipfile.readEntry();
                zipfile.on("entry", (entry) => {
                    if (entry.fileName.startsWith('villageofSpecificState')) {
                        console.log("Found village file:", entry.fileName);
                        zipfile.openReadStream(entry, (err, stream) => {
                            if (err) return reject(err);
                            const saxStream = sax.createStream(true, { trim: true });
                            let inRow = false, inCell = false, inData = false, cellIndex = 0, currentData = "";
                            let currentRow = [], chunk = [], chunkIndex = 0, rowCount = 0;

                            const flushChunk = async () => {
                                if (chunk.length === 0) return;
                                const p = path.join(CHUNKS_DIR, `village_${d}_${chunkIndex}.json`);
                                fs.writeFileSync(p, JSON.stringify(chunk));
                                
                                const copyQuery = `COPY staging.geography_imports (batch_id, entity_type, entity_code, parent_code, entity_name, raw_data, classification) FROM STDIN`;
                                const pgStream = client.query(copyFrom(copyQuery));
                                for(const r of chunk) {
                                    if(r.length >= 7 && r[5]) {
                                        pgStream.write(`${batchId}\tVILLAGE\t${r[5]}\t${r[3]}\t${(r[7] || r[8] || '').replace(/[\t\n]/g, '')}\t{}\tPENDING\n`);
                                    }
                                }
                                pgStream.end();
                                await new Promise((res, rej) => { pgStream.on('finish', res); pgStream.on('error', rej); });
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
                                    if (currentRow.length > 0 && currentRow[0] && !String(currentRow[0]).includes('S.')) {
                                        chunk.push(currentRow);
                                        rowCount++;
                                        if (chunk.length >= 1000) {
                                            saxStream.pause();
                                            await flushChunk();
                                            saxStream.resume();
                                        }
                                    }
                                }
                            });
                            saxStream.on('end', async () => {
                                await flushChunk();
                                console.log(`Finished ${entry.fileName}. Extracted ${rowCount} rows.`);
                                zipfile.readEntry();
                            });
                            saxStream.on('error', (err) => reject(err));
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

    clearInterval(hbInterval);
    await client.end();
    console.log("R2 Process Pipeline Successful.");
}
run().catch(e => { console.error(e); process.exit(1); });
