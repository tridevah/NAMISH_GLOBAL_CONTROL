const fs = require('fs');
const path = require('path');
const yauzl = require('yauzl');
const XLSX = require('xlsx');

const manifestPath = 'D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826/sealed_manifest_r15.json';
const manifest = JSON.parse(fs.readFileSync(manifestPath));
const baseDir = 'D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826';

async function run() {
    let blockEntries = manifest.entries.filter(e => e.logical_outputs.some(l => l.logical_entity === 'BLOCK'));
    
    for (let entry of blockEntries) {
        let zipName = entry.path.split('!')[0];
        let zipPath = path.join(baseDir, zipName);
        let buf = await readZipFile(zipPath, 'block');
        
        let wb = XLSX.read(buf, {type: 'buffer'});
        let ws = wb.Sheets[wb.SheetNames[0]];
        let rawRows = XLSX.utils.sheet_to_json(ws, {header:1, defval:''});
        
        let headerIdx = rawRows.findIndex(r => r[0] && String(r[0]).toLowerCase().includes('s.no') || String(r[0]).toLowerCase().includes('s. no'));
        let exactHeader = rawRows[headerIdx];
        
        let blockNameKey = exactHeader.find(h => h && String(h).toLowerCase().includes('block name'));
        
        console.log(`[${zipName.split('/')[0]}] -> ${blockNameKey ? JSON.stringify(blockNameKey) : 'NOT FOUND'}`);
        if(zipName.includes('UTTAR PRADESH')) {
            let b1000 = rawRows.find(r => r.includes(1000) || r.includes('1000'));
            console.log('UP Block 1000 Exact Row:', JSON.stringify(b1000));
            console.log('UP Exact Header:', JSON.stringify(exactHeader));
        }
    }
}

function readZipFile(zipPath, keyword) {
    return new Promise((resolve, reject) => {
        yauzl.open(zipPath, {lazyEntries: true}, (err, zf) => {
            if (err) return reject(err);
            zf.readEntry();
            zf.on('entry', (e) => {
                if (e.fileName.toLowerCase().includes(keyword.toLowerCase())) {
                    zf.openReadStream(e, (err, stream) => {
                        let buffers = [];
                        stream.on('data', d => buffers.push(d));
                        stream.on('end', () => resolve(Buffer.concat(buffers)));
                    });
                } else {
                    zf.readEntry();
                }
            });
            zf.on('end', () => reject(new Error('File not found in zip: ' + keyword)));
        });
    });
}

run().catch(console.error);
