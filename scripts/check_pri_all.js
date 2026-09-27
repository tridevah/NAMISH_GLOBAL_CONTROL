const yauzl = require('yauzl');
const sax = require('sax');
const fs = require('fs');

const ZIP_DIR = 'D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826';
const files = fs.readdirSync(ZIP_DIR, {withFileTypes:true})
    .filter(d => d.isDirectory())
    .map(d => fs.readdirSync(ZIP_DIR + '/' + d.name).filter(f => f.endsWith('.zip')).map(f => ZIP_DIR + '/' + d.name + '/' + f))
    .flat();

function processZip(zipPath) {
    return new Promise((resolve) => {
        yauzl.open(zipPath, {lazyEntries:true}, (err, zf) => {
            if (err) return resolve();
            zf.readEntry();
            zf.on('entry', entry => {
                if (entry.fileName.includes('priLb')) {
                    zf.openReadStream(entry, (err, stream) => {
                        let seen = new Set();
                        let result = {};
                        const saxStream = sax.createStream(true, { trim: true });
                        let inRow = false, inCell = false, inData = false, currentRow = [], cellData = '';
                        saxStream.on('opentag', tag => {
                            if (tag.name === 'Row') { inRow = true; currentRow = []; }
                            else if (inRow && tag.name === 'Cell') { inCell = true; cellData = ''; }
                            else if (inCell && tag.name === 'Data') { inData = true; }
                        });
                        saxStream.on('text', t => { if (inData) cellData += t; });
                        saxStream.on('closetag', tag => {
                            if (tag === 'Data') inData = false;
                            else if (tag === 'Cell') { currentRow.push(cellData.trim()); inCell = false; }
                            else if (tag === 'Row') { 
                                inRow = false;
                                if (currentRow[1] && !seen.has(currentRow[1])) {
                                    seen.add(currentRow[1]);
                                    result[currentRow[1]] = currentRow[2];
                                }
                            }
                        });
                        saxStream.on('end', () => resolve({path: zipPath, types: result}));
                        stream.pipe(saxStream);
                    });
                } else {
                    zf.readEntry();
                }
            });
            zf.on('end', () => resolve());
        });
    });
}

async function run() {
    for (let f of files) {
        const res = await processZip(f);
        if (res && res.types) console.log(f.split('/').pop(), res.types);
    }
}
run();
