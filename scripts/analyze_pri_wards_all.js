const fs = require('fs');
const path = require('path');
const yauzl = require('yauzl');
const XLSX = require('xlsx');
const crypto = require('crypto');

const SRC = 'D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826';
const states = fs.readdirSync(SRC).filter(d => fs.statSync(path.join(SRC, d)).isDirectory());

let results = [];
let targetStates = ['ANDAMAN AND NICOBAR ISLANDS', 'BIHAR', 'MADHYA PRADESH'];
let fixtures = {};

function processState(index) {
    if (index >= states.length) {
        fs.writeFileSync('D:/NAMISH_GLOBAL_CONTROL/scripts/pri_wards_inventory.json', JSON.stringify({results, fixtures}, null, 2));
        return;
    }
    const state = states[index];
    const stateDir = path.join(SRC, state);
    const zips = fs.readdirSync(stateDir).filter(f => f.endsWith('.zip'));
    if (zips.length === 0) return processState(index + 1);
    
    const zipPath = path.join(stateDir, zips[0]);
    const zipBuffer = fs.readFileSync(zipPath);
    const outerSha = crypto.createHash('sha256').update(zipBuffer).digest('hex');
    
    yauzl.fromBuffer(zipBuffer, {lazyEntries: true}, (err, zf) => {
        if (err) throw err;
        let found = false;
        zf.readEntry();
        zf.on('entry', (e) => {
            if (e.fileName.includes('priWards')) {
                found = true;
                zf.openReadStream(e, (err, stream) => {
                    let buffers = [];
                    stream.on('data', d => buffers.push(d));
                    stream.on('end', () => {
                        let buf = Buffer.concat(buffers);
                        let innerSha = crypto.createHash('sha256').update(buf).digest('hex');
                        let wb = XLSX.read(buf, {type: 'buffer'});
                        let ws = wb.Sheets[wb.SheetNames[0]];
                        
                        let range = XLSX.utils.decode_range(ws['!ref'] || 'A1:A1');
                        let lastWsRow = range.e.r + 1;
                        
                        let rows = XLSX.utils.sheet_to_json(ws, {header:1, defval:''});
                        
                        let firstNonEmpty = rows.findIndex(r => r.some(c => String(c).trim() !== '')) + 1;
                        let headerIdx = rows.findIndex(r => String(r[0]).toLowerCase().includes('s.no'));
                        let firstDataRow = headerIdx >= 0 ? headerIdx + 2 : null;
                        
                        let dataRows = [];
                        let nonDataRows = 0;
                        if (headerIdx >= 0) {
                            nonDataRows = headerIdx + 1;
                            for (let i = headerIdx + 1; i < rows.length; i++) {
                                if (rows[i].some(c => String(c).trim() !== '')) {
                                    dataRows.push({ rowIndex: i + 1, data: rows[i] });
                                } else {
                                    nonDataRows++;
                                }
                            }
                        }
                        
                        let lastDataRow = dataRows.length > 0 ? dataRows[dataRows.length - 1].rowIndex : null;
                        
                        let codes = new Set();
                        let blanks = 0;
                        let duplicates = 0;
                        let codeIdx = headerIdx >= 0 ? rows[headerIdx].findIndex(c => String(c).toLowerCase().trim() === 'ward code') : -1;
                        
                        if (codeIdx >= 0) {
                            for (let r of dataRows) {
                                let code = r.data[codeIdx];
                                if (!code || String(code).trim() === '') blanks++;
                                else {
                                    if (codes.has(code)) duplicates++;
                                    codes.add(code);
                                }
                            }
                        }
                        
                        results.push({
                            state_ut: state,
                            relative_zip_path: zips[0],
                            outer_zip_sha256: outerSha,
                            internal_member: e.fileName,
                            member_sha256: innerSha,
                            sheet_name: wb.SheetNames[0],
                            first_nonempty_row: firstNonEmpty,
                            detected_header_row: headerIdx + 1,
                            first_data_row: firstDataRow,
                            last_data_row: lastDataRow,
                            last_worksheet_row_index: lastWsRow,
                            non_data_row_count: rows.length - dataRows.length,
                            physical_data_row_count: dataRows.length,
                            parsed_data_row_count: dataRows.length,
                            distinct_numeric_ward_code_count: codes.size,
                            blank_ward_code_count: blanks,
                            duplicate_ward_code_count: duplicates,
                            worksheet_limit_reached: lastWsRow >= 65536 || dataRows.length >= 65530,
                            truncation_status: lastWsRow >= 65536 ? 'CAP_REACHED' : (dataRows.length >= 65500 ? 'NEAR_CAP' : 'OK')
                        });
                        
                        if (targetStates.includes(state)) {
                            let fix = {
                                first10: rows.slice(0, Math.min(10, headerIdx + 11)).map((r, idx) => ({row: idx+1, data: r})),
                                last10: dataRows.slice(-10)
                            };
                            fixtures[state] = fix;
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
