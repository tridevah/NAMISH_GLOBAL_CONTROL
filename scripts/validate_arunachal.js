const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const yauzl = require('yauzl');
const XLSX = require('xlsx');

const SRC = 'D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826';
const state = 'ARUNACHAL PRADESH';
const stateDir = path.join(SRC, state);
const zips = fs.readdirSync(stateDir).filter(f => f.endsWith('.zip') && !f.startsWith('INVALID'));

if (zips.length === 0) {
    console.log('No new ZIP found.');
    process.exit(0);
}

const zipPath = path.join(stateDir, zips[0]);
const badZipPath = path.join(stateDir, 'INVALID_SOURCE_DUPLICATE_downloadDir2026_08_26_23_56_32_567.zip');

const newHash = crypto.createHash('sha256').update(fs.readFileSync(zipPath)).digest('hex');
const badHash = crypto.createHash('sha256').update(fs.readFileSync(badZipPath)).digest('hex');

if (newHash === badHash) {
    console.log('FAIL: Source hash is identical to the duplicated Andhra Pradesh ZIP.');
    process.exit(1);
}

yauzl.open(zipPath, {lazyEntries: true}, (err, zf) => {
    if (err) throw err;
    let validated = { stateCode: null, stateName: null, ok: true };
    
    zf.readEntry();
    zf.on('entry', (e) => {
        if (e.fileName.includes('districtofSpecific')) {
            zf.openReadStream(e, (err, stream) => {
                let buffers = [];
                stream.on('data', d => buffers.push(d));
                stream.on('end', () => {
                    let buf = Buffer.concat(buffers);
                    let wb = XLSX.read(buf, {type: 'buffer'});
                    let ws = wb.Sheets[wb.SheetNames[0]];
                    let rows = XLSX.utils.sheet_to_json(ws, {header:1, defval:''});
                    
                    let titleRow = String(rows[1][0]);
                    let match = titleRow.match(/All Districts of (.*?)\(State Code:(\d+)\)/i);
                    if (match) {
                        validated.stateName = match[1].trim().toUpperCase();
                        validated.stateCode = match[2];
                    }
                    console.log('Detected State Name:', validated.stateName);
                    console.log('Detected State Code:', validated.stateCode);
                    console.log('Hash match with AP?', newHash === badHash);
                    zf.readEntry();
                });
            });
        } else {
            zf.readEntry();
        }
    });
});
