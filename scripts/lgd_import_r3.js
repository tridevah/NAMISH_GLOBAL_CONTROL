const fs = require('fs');
const path = require('path');
const yauzl = require('yauzl');
const sax = require('sax');
const { Client } = require('pg');
const crypto = require('crypto');
const { from: copyFrom } = require('pg-copy-streams');

const RUNTIME_DIR = 'D:\\ANTIGRAVITY_WORKSPACE\\LGD_IMPORT_RUNTIME';
const CHUNKS_DIR = path.join(RUNTIME_DIR, 'chunks');
const STOP_MARKER = path.join(RUNTIME_DIR, 'STOP_REQUESTED');
const MANIFEST_PATH = 'D:\\ANTIGRAVITY_WORKSPACE\\INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826\\sealed_manifest.json';
const DB_URL = 'postgresql://postgres:postgres@127.0.0.1:54522/postgres';

async function run() {
    if (fs.existsSync(STOP_MARKER)) fs.unlinkSync(STOP_MARKER); 

    const manifest = JSON.parse(fs.readFileSync(MANIFEST_PATH, 'utf8'));
    fs.writeFileSync(path.join(RUNTIME_DIR, 'importer_r3.pid'), String(process.pid));
    
    const hbInterval = setInterval(() => {
        fs.writeFileSync(path.join(RUNTIME_DIR, 'heartbeat_r3.json'), JSON.stringify({ pid: process.pid, time: new Date().toISOString(), expected_batches: manifest.entries.length }));
    }, 1000);

    const client = new Client({ connectionString: DB_URL });
    await client.connect();

    const relRes = await client.query(`SELECT id FROM data_imports.releases WHERE release_name='LGD_20260826_CORE_R2'`);
    const releaseId = relRes.rows[0].id;
    
    const batchQ = `INSERT INTO data_imports.batches (release_id, entity_type, status) VALUES ('${releaseId}', 'VILLAGE_R3', 'PENDING') ON CONFLICT DO NOTHING RETURNING id`;
    let batchRes = await client.query(batchQ);
    let batchId = batchRes.rows.length ? batchRes.rows[0].id : (await client.query(`SELECT id FROM data_imports.batches WHERE release_id='${releaseId}' AND entity_type='VILLAGE_R3'`)).rows[0].id;

    console.log("Starting R3 extraction from sealed manifest...");

    for (const entry of manifest.entries) {
        if (fs.existsSync(STOP_MARKER)) {
            console.log("Graceful STOP_REQUESTED detected. Halting pipeline safely.");
            break;
        }
        if (entry.role !== 'IMPORT_AUTHORITY') continue;
        if (!entry.path.includes('.zip!villageofSpecificState')) continue;
        
        const [zipPart, internalFile] = entry.path.split('!');
        const absoluteZipPath = path.join('D:\\ANTIGRAVITY_WORKSPACE\\INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826', zipPart);
        
        console.log("Processing:", entry.path);
        
        await new Promise((resolve, reject) => {
            yauzl.open(absoluteZipPath, { lazyEntries: true }, (err, zipfile) => {
                if (err) return reject(err);
                zipfile.readEntry();
                zipfile.on("entry", (e) => {
                    if (e.fileName === internalFile) {
                        zipfile.openReadStream(e, (err, stream) => {
                            if (err) return reject(err);
                            const saxStream = sax.createStream(true, { trim: true });
                            let inRow = false, inCell = false, inData = false, cellIndex = 0, currentData = "";
                            let currentRow = [], chunk = [], chunkIndex = 0;

                            const flushChunk = async () => {
                                if (chunk.length === 0) return;
                                const pTemp = path.join(CHUNKS_DIR, `R3_${entry.source_sha256}_${chunkIndex}.partial`);
                                const pFinal = path.join(CHUNKS_DIR, `R3_${entry.source_sha256}_${chunkIndex}.tsv`);
                                
                                const tsvData = chunk.map(r => r.map(c => c ? String(c).replace(/\t|\n/g, '') : '').join('\t')).join('\n');
                                fs.writeFileSync(pTemp, tsvData + '\n');
                                fs.renameSync(pTemp, pFinal);
                                
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
    console.log("R3 Process Completed or Stopped Gracefully.");
}
run().catch(e => { console.error(e); process.exit(1); });
