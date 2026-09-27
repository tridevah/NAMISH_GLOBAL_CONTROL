const fs = require('fs');
const XLSX = require('xlsx');
const yauzl = require('yauzl');

function analyzePRIWards(zipPath, targetFile) {
    yauzl.open(zipPath, {lazyEntries: true}, (err, zf) => {
        if (err) throw err;
        zf.readEntry();
        zf.on('entry', (e) => {
            if (e.fileName === targetFile) {
                zf.openReadStream(e, (err, stream) => {
                    let buffers = [];
                    stream.on('data', d => buffers.push(d));
                    stream.on('end', () => {
                        let buf = Buffer.concat(buffers);
                        let wb = XLSX.read(buf, {type: 'buffer'});
                        let ws = wb.Sheets[wb.SheetNames[0]];
                        let rows = XLSX.utils.sheet_to_json(ws, {header:1, defval:''});
                        
                        let headerIdx = rows.findIndex(r => String(r[0]).toLowerCase().includes('s.no'));
                        let header = rows[headerIdx].map(c=>String(c).toLowerCase().trim().replace(/\r?\n/g, ' '));
                        
                        let codeIdx = header.findIndex(c => c.includes('ward code'));
                        let data = rows.slice(headerIdx+1).filter(r => r[0]);
                        let codes = {};
                        for (let r of data) {
                            let code = r[codeIdx];
                            if (!codes[code]) codes[code] = [];
                            codes[code].push({
                                row: r[0],
                                lbcode: r[header.findIndex(c => c.includes('local body code'))]
                            });
                        }
                        
                        let dups = Object.entries(codes).filter(e => e[1].length > 1);
                        console.log('Total Data Rows:', data.length);
                        console.log('Distinct Codes:', Object.keys(codes).length);
                        console.log('Duplicate Code Groups:', dups.length);
                        
                        for (let i = 0; i < Math.min(5, dups.length); i++) {
                            console.log('Code:', dups[i][0]);
                            console.log(dups[i][1]);
                        }
                    });
                });
            } else {
                zf.readEntry();
            }
        });
    });
}
analyzePRIWards('D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826/BIHAR/downloadDir2026_08_27_00_00_37_836.zip', 'priWards2026:08:27:00:01:03:112.xls');
