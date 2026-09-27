const fs = require('fs');
const path = require('path');
const XLSX = require('xlsx');

const SRC = 'D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826/ANDAMAN AND NICOBAR ISLANDS/downloadDir2026_08_26_23_55_42_288.zip!districtofSpecificState2026:08:26:23:55:42:321.xls';
const yauzl = require('yauzl');

function inspectZip(zipPath, targetFile) {
    yauzl.open(zipPath, {lazyEntries: true}, (err, zf) => {
        if (err) throw err;
        zf.readEntry();
        zf.on('entry', (e) => {
            if (e.fileName === targetFile || !targetFile) {
                zf.openReadStream(e, (err, stream) => {
                    let buffers = [];
                    stream.on('data', d => buffers.push(d));
                    stream.on('end', () => {
                        let buf = Buffer.concat(buffers);
                        let wb = XLSX.read(buf, {type: 'buffer'});
                        let ws = wb.Sheets[wb.SheetNames[0]];
                        let rows = XLSX.utils.sheet_to_json(ws, {header:1, defval:''});
                        let headerIdx = rows.findIndex(r => String(r[0]).toLowerCase().includes('s.no'));
                        if(headerIdx >= 0) console.log(e.fileName, 'HEADERS:', rows[headerIdx].slice(0,10));
                        if(headerIdx >= 0 && rows.length > headerIdx+1) console.log('ROW 1:', rows[headerIdx+1].slice(0,10));
                        zf.readEntry();
                    });
                });
            } else {
                zf.readEntry();
            }
        });
    });
}
inspectZip('D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826/ANDAMAN AND NICOBAR ISLANDS/downloadDir2026_08_26_23_55_42_288.zip');
