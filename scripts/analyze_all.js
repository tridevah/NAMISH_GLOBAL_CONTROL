const fs = require('fs');
const XLSX = require('xlsx');
const yauzl = require('yauzl');

function analyzeAll(zipPath) {
    yauzl.open(zipPath, {lazyEntries: true}, (err, zf) => {
        if (err) throw err;
        zf.readEntry();
        zf.on('entry', (e) => {
            if (e.fileName.endsWith('.xls')) {
                zf.openReadStream(e, (err, stream) => {
                    let buffers = [];
                    stream.on('data', d => buffers.push(d));
                    stream.on('end', () => {
                        let buf = Buffer.concat(buffers);
                        let wb = XLSX.read(buf, {type: 'buffer'});
                        let ws = wb.Sheets[wb.SheetNames[0]];
                        let rows = XLSX.utils.sheet_to_json(ws, {header:1, defval:''});
                        
                        let headerIdx = rows.findIndex(r => String(r[0]).toLowerCase().includes('s.no'));
                        if (headerIdx >= 0) {
                            let header = rows[headerIdx].map(c=>String(c).toLowerCase().trim().replace(/\r?\n/g, ' '));
                            let codeIdx = header.findIndex(c => c.includes('code') && !c.includes('parent') && !c.includes('type') && !c.includes('census') && !c.includes('district code') && !c.includes('sub-district code') && !c.includes('subdistrict code') && !c.includes('state'));
                            if (e.fileName.includes('districtof')) codeIdx = header.findIndex(c => c === 'district code');
                            if (e.fileName.includes('subDistrict')) codeIdx = header.findIndex(c => c === 'subdistrict code');
                            if (e.fileName.includes('villageof')) codeIdx = header.findIndex(c => c === 'village code');
                            if (e.fileName.includes('blockof')) codeIdx = header.findIndex(c => c === 'block code');
                            
                            if (codeIdx >= 0) {
                                let data = rows.slice(headerIdx+1).filter(r => r[0]);
                                let codes = new Set();
                                for (let r of data) codes.add(r[codeIdx]);
                                console.log(e.fileName, '- Rows:', data.length, '- Distinct Codes:', codes.size);
                            }
                        }
                        zf.readEntry();
                    });
                });
            } else {
                zf.readEntry();
            }
        });
    });
}
analyzeAll('D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826/BIHAR/downloadDir2026_08_27_00_00_37_836.zip');
