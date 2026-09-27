const fs = require('fs');
const path = require('path');
const yauzl = require('yauzl');
const XLSX = require('xlsx');

const SRC = 'D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826';
const state = 'ARUNACHAL PRADESH';
const stateDir = path.join(SRC, state);
const zips = fs.readdirSync(stateDir).filter(f => f.endsWith('.zip'));

yauzl.open(path.join(stateDir, zips[0]), {lazyEntries: true}, (err, zf) => {
    if (err) throw err;
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
                    
                    let headerIdx = rows.findIndex(r => r[0] && String(r[0]).toLowerCase().includes('s.no') || String(r[0]).toLowerCase().includes('s. no'));
                    let header = rows[headerIdx].map(c=>String(c).toLowerCase().trim().replace(/\r?\n/g, ' '));
                    let codeIdx = header.findIndex(c => c === 'district code');
                    let nameIdx = header.findIndex(c => c === 'district name');
                    let data = rows.slice(headerIdx+1).filter(r => r[codeIdx] && !isNaN(parseInt(r[codeIdx])));
                    
                    console.log("Total Districts in Arunachal Pradesh ZIP:", data.length);
                    console.log("First 5 Districts:");
                    for (let i = 0; i < 5; i++) console.log(data[i][codeIdx], data[i][nameIdx]);
                });
            });
        } else {
            zf.readEntry();
        }
    });
});
