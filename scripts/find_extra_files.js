const fs = require('fs');
const path = require('path');
const m = JSON.parse(fs.readFileSync('D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826/sealed_manifest_r13.json', 'utf8'));

const manifestOuterPaths = new Set(m.entries.map(e => e.path.split('!')[0]));

const SRC = 'D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826';
const states = fs.readdirSync(SRC).filter(d => fs.statSync(path.join(SRC, d)).isDirectory());

let extraFiles = [];
for (const state of states) {
    const stateDir = path.join(SRC, state);
    const files = fs.readdirSync(stateDir).filter(f => f.endsWith('.zip') || f.endsWith('.xlsx') || f.endsWith('.csv'));
    for (const f of files) {
        const fullPath = (state + '/' + f);
        if (!manifestOuterPaths.has(fullPath) && !manifestOuterPaths.has(f)) {
            extraFiles.push(fullPath);
        }
    }
}
console.log('Extra files:', extraFiles);
