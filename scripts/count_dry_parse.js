const fs = require('fs');
const path = require('path');
const SRC = 'D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826';
let count = 0;
const states = fs.readdirSync(SRC).filter(d => fs.statSync(path.join(SRC, d)).isDirectory());
for (const state of states) {
    const stateDir = path.join(SRC, state);
    const files = fs.readdirSync(stateDir);
    for (const file of files) {
        if (file.endsWith('.zip') || file.endsWith('.xlsx') || file.endsWith('.csv')) count++;
    }
}
console.log('Parsed outer files:', count);
