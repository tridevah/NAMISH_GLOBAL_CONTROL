const yauzl = require('yauzl');
const XLSX = require('xlsx');

yauzl.open('D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826/BIHAR/downloadDir2026_08_27_00_00_37_836.zip', {lazyEntries: true}, (err, zf) => {
    if (err) throw err;
    zf.readEntry();
    zf.on('entry', (e) => {
        if (e.fileName === 'priWards2026:08:27:00:01:03:112.xls') {
            zf.openReadStream(e, (err, stream) => {
                let buffers = [];
                stream.on('data', d => buffers.push(d));
                stream.on('end', () => {
                    let buf = Buffer.concat(buffers);
                    let wb = XLSX.read(buf, {type: 'buffer'});
                    let ws = wb.Sheets[wb.SheetNames[0]];
                    let rows = XLSX.utils.sheet_to_json(ws, {header:1, defval:''});
                    let headerIdx = rows.findIndex(r => String(r[0]).toLowerCase().includes('s.no'));
                    console.log(rows[headerIdx].map(c=>String(c).toLowerCase().trim().replace(/\r?\n/g, ' ')));
                    zf.readEntry();
                });
            });
        } else {
            zf.readEntry();
        }
    });
});
