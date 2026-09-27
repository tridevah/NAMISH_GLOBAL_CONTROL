const fs = require('fs');
const path = require('path');
const yauzl = require('yauzl');
const sax = require('sax');

const SOURCE_DIR = 'D:\\ANTIGRAVITY_WORKSPACE\\INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826';

function getHeaderRowFromXmlStream(stream) {
    return new Promise((resolve) => {
        const ss = sax.createStream(true, {trim: true});
        let inRow = false, inCell = false, cellIndex = 0, currentData = '';
        let row = [];
        let rowCount = 0;
        let headerRow = null;
        
        ss.on('opentag', n => { 
            if(n.name === 'Row') { inRow = true; row = []; cellIndex = 0; } 
            else if(n.name === 'Cell') { 
                inCell = true; currentData = ''; 
                if(n.attributes['ss:Index']) cellIndex = parseInt(n.attributes['ss:Index'], 10) - 1; 
            } 
        });
        ss.on('text', t => { if(inCell) currentData += t; });
        ss.on('closetag', n => { 
            if(n === 'Cell') { row[cellIndex++] = currentData; inCell = false; } 
            else if(n === 'Row') { 
                rowCount++; 
                if (row.length > 0 && row[0] && String(row[0]).toLowerCase().replace(/\s/g, '').includes('s.no')) {
                    headerRow = [...row];
                    resolve(headerRow);
                } else if (rowCount > 10) {
                    if (!headerRow) resolve(null);
                }
            } 
        });
        ss.on('end', () => resolve(headerRow));
        ss.on('error', (err) => resolve(null));
        stream.pipe(ss);
    });
}

function getHeaderRowFromCsvStream(stream) {
    return new Promise((resolve) => {
        let buffer = '';
        stream.on('data', chunk => {
            buffer += chunk.toString();
            const lines = buffer.split('\n');
            if (lines.length > 1) {
                resolve(lines[0].trim().split(','));
                stream.destroy();
            }
        });
        stream.on('end', () => { resolve(buffer.split('\n')[0].trim().split(',')); });
    });
}

async function scan() {
    const items = fs.readdirSync(SOURCE_DIR);
    let signatures = {};

    for (const stateName of items) {
        const statePath = path.join(SOURCE_DIR, stateName);
        if (fs.statSync(statePath).isDirectory()) {
            const files = fs.readdirSync(statePath);
            for (const file of files) {
                const filePath = path.join(statePath, file);
                
                if (file.endsWith('.zip')) {
                    await new Promise(resolve => {
                        yauzl.open(filePath, { lazyEntries: true }, (err, zipfile) => {
                            if(err) return resolve();
                            zipfile.readEntry();
                            zipfile.on('entry', async (entry) => {
                                const eName = entry.fileName.toLowerCase().replace(/[^a-z_]/g, '');
                                if (eName.includes('allblockstatewithcoveredvillage') ||
                                    eName.includes('villagegrampanchayatmapping') ||
                                    eName.includes('ulbwardforstate') ||
                                    eName.includes('priwards') ||
                                    eName.includes('prilbspecificstate') ||
                                    eName.includes('statewiseulbscoverage')) {
                                    
                                    await new Promise(resStream => {
                                        zipfile.openReadStream(entry, async (err, stream) => {
                                            if (err) return resStream();
                                            const headers = await getHeaderRowFromXmlStream(stream);
                                            if (headers) {
                                                const sig = JSON.stringify(headers.filter(h => h).map(h=>h.toLowerCase().trim()));
                                                if (!signatures[eName]) signatures[eName] = new Set();
                                                if (!signatures[eName].has(sig)) {
                                                    signatures[eName].add(sig);
                                                    console.log(`[NEW SIGNATURE] ${eName} => ${sig}`);
                                                }
                                            }
                                            resStream();
                                        });
                                    });
                                }
                                zipfile.readEntry();
                            });
                            zipfile.on('end', resolve);
                        });
                    });
                }
            }
        } else if (stateName === 'pincode.csv') {
            await new Promise(res => {
                const stream = fs.createReadStream(statePath);
                getHeaderRowFromCsvStream(stream).then(h => {
                    console.log(`[NEW SIGNATURE] pincode.csv => ${JSON.stringify(h)}`);
                    res();
                });
            });
        }
    }
}
scan().catch(console.error);
