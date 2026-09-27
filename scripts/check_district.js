const fs = require('fs');
const yauzl = require('yauzl');
const XLSX = require('xlsx');

yauzl.open('D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826/ANDAMAN AND NICOBAR ISLANDS/downloadDir2026_08_26_23_55_42_288.zip', {lazyEntries: true}, (err, zf) => {
    if (err) throw err;
    zf.readEntry();
    zf.on('entry', (e) => {
        if (e.fileName.includes('districtofSpecificState')) {
            zf.openReadStream(e, (err, stream) => {
                let buffers = [];
                stream.on('data', d => buffers.push(d));
                stream.on('end', () => {
                    let buf = Buffer.concat(buffers);
                    let wb = XLSX.read(buf, {type: 'buffer'});
                    let ws = wb.Sheets[wb.SheetNames[0]];
                    let rows = XLSX.utils.sheet_to_json(ws, {header:1, defval:''});
                    let headerIdx = rows.findIndex(r => String(r[0]).toLowerCase().includes('s.no'));
                    console.log('Headers:', rows[headerIdx]);
                    console.log('Row 1:', rows[headerIdx+2]);
                    zf.readEntry();
                });
            });
        } else {
            zf.readEntry();
        }
    });
});
