const fs = require('fs');
const path = require('path');
const yauzl = require('yauzl');
const XLSX = require('xlsx');

const manifestPath = 'D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826/sealed_manifest_r15.json';
const manifest = JSON.parse(fs.readFileSync(manifestPath));
const baseDir = 'D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826';

async function run() {
    let blockEntries = manifest.entries.filter(e => e.logical_outputs.some(l => l.logical_entity === 'BLOCK'));
    let totalDuplicates = 0;
    
    for (let entry of blockEntries) {
        let zipName = entry.path.split('!')[0];
        let zipPath = path.join(baseDir, zipName);
        let buf = await readZipFile(zipPath, 'block');
        
        let wb = XLSX.read(buf, {type: 'buffer'});
        let ws = wb.Sheets[wb.SheetNames[0]];
        let rawRows = XLSX.utils.sheet_to_json(ws, {header:1, defval:''});
        
        let headerIdx = rawRows.findIndex(r => r[0] && String(r[0]).toLowerCase().includes('s.no') || String(r[0]).toLowerCase().includes('s. no'));
        let exactHeader = rawRows[headerIdx];
        
        let nameHeaders = exactHeader.filter(h => h && String(h).toLowerCase().trim() === 'block name');
        if(nameHeaders.length > 1) {
            console.log(`[${zipName.split('/')[0]}] -> DUPLICATE 'Block Name' headers: ${nameHeaders.length}`);
            totalDuplicates++;
        }
    }
    console.log("Total states with duplicate block name headers:", totalDuplicates);
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
