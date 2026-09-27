const fs = require('fs');
const path = require('path');
const yauzl = require('yauzl');
const XLSX = require('xlsx');

const SRC = 'D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826';
const states = fs.readdirSync(SRC).filter(d => fs.statSync(path.join(SRC, d)).isDirectory());

let results = {
    STATE_UT: { count: 0, distinctCodes: new Set() },
    DISTRICT: { count: 0, distinctCodes: new Set() },
    SUB_DISTRICT: { count: 0, distinctCodes: new Set() },
    BLOCK: { count: 0, distinctCodes: new Set() }
};

let errors = [];
let mappings = {
    districtToState: {},
    subDistrictToDistrict: {},
    blockToDistrict: {}
};

function processState(index) {
    if (index >= states.length) {
        console.log("STATES:", results.STATE_UT.distinctCodes.size);
        console.log("DISTRICTS:", results.DISTRICT.count, "Distinct:", results.DISTRICT.distinctCodes.size);
        console.log("SUB_DISTRICTS:", results.SUB_DISTRICT.count, "Distinct:", results.SUB_DISTRICT.distinctCodes.size);
        console.log("BLOCKS:", results.BLOCK.count, "Distinct:", results.BLOCK.distinctCodes.size);
        fs.writeFileSync('D:/NAMISH_GLOBAL_CONTROL/scripts/core_import_preflight.json', JSON.stringify({
            counts: {
                STATE_UT: results.STATE_UT.distinctCodes.size,
                DISTRICT: results.DISTRICT.count,
                SUB_DISTRICT: results.SUB_DISTRICT.count,
                BLOCK: results.BLOCK.count
            },
            distinct: {
                STATE_UT: results.STATE_UT.distinctCodes.size,
                DISTRICT: results.DISTRICT.distinctCodes.size,
                SUB_DISTRICT: results.SUB_DISTRICT.distinctCodes.size,
                BLOCK: results.BLOCK.distinctCodes.size
            }
        }));
        return;
    }
    const state = states[index];
    const stateDir = path.join(SRC, state);
    const zips = fs.readdirSync(stateDir).filter(f => f.endsWith('.zip'));
    if (zips.length === 0) return processState(index + 1);
    
    yauzl.open(path.join(stateDir, zips[0]), {lazyEntries: true}, (err, zf) => {
        if (err) throw err;
        let filesToProcess = 3; // district, subdistrict, block
        
        zf.readEntry();
        zf.on('entry', (e) => {
            if (e.fileName.includes('districtofSpecific') || e.fileName.includes('subDistrictofSpecific') || e.fileName.includes('blockofspecific')) {
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
                            
                            if (e.fileName.includes('districtofSpecific')) {
                                let match = String(rows[1][0]).match(/State Code:(\d+)/i);
                                if (match) results.STATE_UT.distinctCodes.add(match[1]);
                                
                                let codeIdx = header.findIndex(c => c === 'district code');
                                let data = rows.slice(headerIdx+2).filter(r => r[0]);
                                results.DISTRICT.count += data.length;
                                for(let r of data) {
                                    results.DISTRICT.distinctCodes.add(r[codeIdx]);
                                    if (match) mappings.districtToState[r[codeIdx]] = match[1];
                                }
                            } else if (e.fileName.includes('subDistrictofSpecific')) {
                                let codeIdx = header.findIndex(c => c === 'subdistrict code' || c === 'sub-district code');
                                let pIdx = header.findIndex(c => c === 'district code');
                                let data = rows.slice(headerIdx+2).filter(r => r[0]);
                                results.SUB_DISTRICT.count += data.length;
                                for(let r of data) {
                                    results.SUB_DISTRICT.distinctCodes.add(r[codeIdx]);
                                    if(pIdx >= 0) mappings.subDistrictToDistrict[r[codeIdx]] = r[pIdx];
                                }
                            } else if (e.fileName.includes('blockofspecific')) {
                                let codeIdx = header.findIndex(c => c === 'block code');
                                let pIdx = header.findIndex(c => c === 'district code');
                                let data = rows.slice(headerIdx+2).filter(r => r[0]);
                                results.BLOCK.count += data.length;
                                for(let r of data) {
                                    results.BLOCK.distinctCodes.add(r[codeIdx]);
                                    if(pIdx >= 0) mappings.blockToDistrict[r[codeIdx]] = r[pIdx];
                                }
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
