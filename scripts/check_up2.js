const fs = require('fs');
const yauzl = require('yauzl');
const XLSX = require('xlsx');

const zipPath = 'D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826/UTTAR PRADESH/downloadDir2026_08_27_00_18_41_967.zip';
const fileName = 'blockofspecificState2026-08-27 00-20-46-042.xls';

yauzl.open(zipPath, {lazyEntries: true}, (err, zf) => {
    if (err) throw err;
    zf.readEntry();
    zf.on('entry', (e) => {
        if (e.fileName === fileName || e.fileName.includes(fileName.replace(/:/g, '-'))) {
            zf.openReadStream(e, (err, stream) => {
                let buffers = [];
                stream.on('data', d => buffers.push(d));
                stream.on('end', () => {
                    let buf = Buffer.concat(buffers);
                    let wb = XLSX.read(buf, {type: 'buffer'});
                    let ws = wb.Sheets[wb.SheetNames[0]];
                    let rawRows = XLSX.utils.sheet_to_json(ws, {header:1, defval:''});
                    console.log('--- UP (Block 1000) ---');
                    console.log('Row 0:', rawRows[0]);
                    console.log('Row 1:', rawRows[1]);
                    console.log('Row 2:', rawRows[2]);
                    
                    let b1000 = rawRows.find(r => r.includes(1000) || r.includes('1000'));
                    console.log('Row 1000:', b1000);
                });
            });
        } else {
            zf.readEntry();
        }
    });
});
