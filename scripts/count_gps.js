const fs = require('fs');
const path = require('path');
const yauzl = require('yauzl');
const XLSX = require('xlsx');

const SRC = 'D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826';
const states = fs.readdirSync(SRC).filter(d => fs.statSync(path.join(SRC, d)).isDirectory());

let totalGP = 0;
let fileCount = 0;

function processState(stateIndex) {
    if (stateIndex >= states.length) {
        console.log('Total GPs:', totalGP, 'across', fileCount, 'files');
        return;
    }
    const state = states[stateIndex];
    const stateDir = path.join(SRC, state);
    const zips = fs.readdirSync(stateDir).filter(f => f.endsWith('.zip'));
    if (zips.length === 0) return processState(stateIndex + 1);
    
    yauzl.open(path.join(stateDir, zips[0]), {lazyEntries: true}, (err, zf) => {
        if (err) throw err;
        let found = false;
        zf.readEntry();
        zf.on('entry', (e) => {
            if (e.fileName.includes('priLbSpecific')) {
                found = true;
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
                            let typeIdx = header.findIndex(c => c.includes('type code'));
                            let data = rows.slice(headerIdx+1).filter(r => r[0]);
                            let gpCount = data.filter(r => String(r[typeIdx]) === '3').length;
                            totalGP += gpCount;
                            fileCount++;
                        }
                        zf.readEntry();
                    });
                });
            } else {
                zf.readEntry();
            }
        });
        zf.on('end', () => processState(stateIndex + 1));
        if (!found) zf.on('end', () => {}); // handled by readEntry finishing
    });
}
processState(0);
