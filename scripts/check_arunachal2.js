const fs = require('fs');
const path = require('path');
const yauzl = require('yauzl');

const SRC = 'D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826';
const state = 'ARUNACHAL PRADESH';
const stateDir = path.join(SRC, state);
const zips = fs.readdirSync(stateDir).filter(f => f.endsWith('.zip'));

yauzl.open(path.join(stateDir, zips[0]), {lazyEntries: true}, (err, zf) => {
    if (err) throw err;
    zf.readEntry();
    zf.on('entry', (e) => {
        console.log(e.fileName);
        zf.readEntry();
    });
});
