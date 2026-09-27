const fs = require('fs');
const path = require('path');
const yauzl = require('yauzl');
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
                    let innerHash = crypto.createHash('sha256');
                    let rawString = '';
                    let keepString = targetStates.includes(state);
                    let rowCount = 0;
                    
                    stream.on('data', d => {
                        innerHash.update(d);
                        if (keepString) {
                            rawString += d.toString('utf8');
                            // we can truncate to save memory if we just want first/last rows, but let's just keep it if it fits
                            // 100MB string is fine for 3 files
                        } else {
                            // count occurrences of <Row
                            let match = d.toString('utf8').match(/<Row/g);
                            if (match) rowCount += match.length;
                        }
                    });
                    
                    stream.on('end', () => {
                        let innerSha = innerHash.digest('hex');
                        
                        if (keepString) {
                            let match = rawString.match(/<Row/g);
                            rowCount = match ? match.length : 0;
                            // Parse XML manually using regex for fixtures
                            let rows = rawString.split(/<Row[^>]*>/).slice(1);
                            let parsedRows = rows.map(r => {
                                let cells = r.split(/<Cell[^>]*>/).slice(1);
                                return cells.map(c => {
                                    let match = c.match(/<Data[^>]*>(.*?)<\/Data>/);
                                    return match ? match[1].replace(/&#10;/g, ' ').replace(/&amp;/g, '&') : '';
                                });
                            });
                            
                            let headerIdx = parsedRows.findIndex(r => r[0] && r[0].toLowerCase().includes('s.no'));
                            let firstDataRow = headerIdx >= 0 ? headerIdx + 2 : null;
                            
                            let dataRows = [];
                            let nonDataRows = 0;
                            if (headerIdx >= 0) {
                                nonDataRows = headerIdx + 1;
                                for (let i = headerIdx + 1; i < parsedRows.length; i++) {
                                    if (parsedRows[i].some(c => String(c).trim() !== '')) {
                                        dataRows.push({ rowIndex: i + 1, data: parsedRows[i] });
                                    } else {
                                        nonDataRows++;
                                    }
                                }
                            }
                            
                            let lastWsRow = parsedRows.length;
                            
                            let codes = new Set();
                            let blanks = 0;
                            let duplicates = 0;
                            let codeIdx = headerIdx >= 0 ? parsedRows[headerIdx].findIndex(c => String(c).toLowerCase().trim() === 'ward code') : -1;
                            
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
                                sheet_name: 'priWards',
                                first_nonempty_row: 1,
                                detected_header_row: headerIdx + 1,
                                first_data_row: firstDataRow,
                                last_data_row: dataRows.length > 0 ? dataRows[dataRows.length - 1].rowIndex : null,
                                last_worksheet_row_index: lastWsRow,
                                non_data_row_count: parsedRows.length - dataRows.length,
                                physical_data_row_count: dataRows.length,
                                parsed_data_row_count: dataRows.length,
                                distinct_numeric_ward_code_count: codes.size,
                                blank_ward_code_count: blanks,
                                duplicate_ward_code_count: duplicates,
                                worksheet_limit_reached: lastWsRow >= 65536 || dataRows.length >= 65530,
                                truncation_status: lastWsRow >= 65536 ? 'CAP_REACHED' : (dataRows.length >= 65500 ? 'NEAR_CAP' : 'OK')
                            });
                            
                            fixtures[state] = {
                                first10: parsedRows.slice(0, Math.min(10, headerIdx + 11)).map((r, idx) => ({row: idx+1, data: r})),
                                last10: dataRows.slice(-10)
                            };
                        } else {
                            // Minimal result for non-target states to avoid memory issues
                            let dataRowsCount = Math.max(0, rowCount - 4); // assuming header + some meta rows
                            results.push({
                                state_ut: state,
                                relative_zip_path: zips[0],
                                outer_zip_sha256: outerSha,
                                internal_member: e.fileName,
                                member_sha256: innerSha,
                                sheet_name: 'priWards',
                                last_worksheet_row_index: rowCount,
                                physical_data_row_count: dataRowsCount,
                                worksheet_limit_reached: rowCount >= 65536 || dataRowsCount >= 65530,
                                truncation_status: rowCount >= 65536 ? 'CAP_REACHED' : (dataRowsCount >= 65500 ? 'NEAR_CAP' : 'OK')
                            });
                        }
                        
                        zf.readEntry();
                    });
                });
            } else {
                zf.readEntry();
            }
        });
        zf.on('end', () => processState(index + 1));
        if (!found) zf.on('end', () => {});
    });
}
processState(0);
