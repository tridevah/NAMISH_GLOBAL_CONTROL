const fs = require('fs');
const XLSX = require('xlsx');
const yauzl = require('yauzl');

function analyzePRI(zipPath, targetFile) {
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
                        
                        let codeIdx = header.findIndex(c => c.includes('localbody code'));
                        let nameIdx = header.findIndex(c => c.includes('localbody name') && !c.includes('type') && !c.includes('parent'));
                        let typeIdx = header.findIndex(c => c.includes('localbody type code'));
                        let typeNameIdx = header.findIndex(c => c.includes('localbody type name'));
                        let parentIdx = header.findIndex(c => c.includes('parent localbody code'));
                        let versionIdx = header.findIndex(c => c.includes('localbody version'));
                        let statusIdx = header.findIndex(c => c.includes('status'));
                        
                        let data = rows.slice(headerIdx+1).filter(r => r[0]);
                        let codes = {};
                        for (let r of data) {
                            let code = r[codeIdx];
                            if (!codes[code]) codes[code] = [];
                            codes[code].push({
                                row: r[0],
                                name: r[nameIdx],
                                type: r[typeIdx],
                                typeName: r[typeNameIdx],
                                parent: r[parentIdx],
                                version: versionIdx >= 0 ? r[versionIdx] : null,
                                status: statusIdx >= 0 ? r[statusIdx] : null
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
analyzePRI('D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826/MADHYA PRADESH/downloadDir2026_08_27_00_08_35_495.zip', 'priLbSpecificState2026:08:27:00:08:43:786.xls');
