const fs = require('fs');
const path = require('path');
const yauzl = require('yauzl');
const XLSX = require('xlsx');

const SRC = 'D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826';
const states = fs.readdirSync(SRC).filter(d => fs.statSync(path.join(SRC, d)).isDirectory());

let codesToStates = {};
let multiple = {};

function processState(index) {
    if (index >= states.length) {
        for (let code in codesToStates) {
            if (codesToStates[code].size > 1) multiple[code] = Array.from(codesToStates[code]);
        }
        console.log(multiple);
        return;
    }
    const state = states[index];
    const stateDir = path.join(SRC, state);
    const zips = fs.readdirSync(stateDir).filter(f => f.endsWith('.zip'));
    if (zips.length === 0) return processState(index + 1);
    
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
                        if (headerIdx >= 0) {
                            let header = rows[headerIdx].map(c=>String(c).toLowerCase().trim().replace(/\r?\n/g, ' '));
                            let codeIdx = header.findIndex(c => c === 'district code');
                            let data = rows.slice(headerIdx+1).filter(r => r[codeIdx] && !isNaN(parseInt(r[codeIdx])));
                            
                            for(let r of data) {
                                let code = r[codeIdx];
                                if(!codesToStates[code]) codesToStates[code] = new Set();
                                codesToStates[code].add(state);
                            }
                        }
                        zf.readEntry();
                    });
                });
            } else {
                zf.readEntry();
            }
        });
        zf.on('end', () => processState(index + 1));
    });
}
processState(0);
