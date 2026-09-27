const fs = require('fs');
const m = JSON.parse(fs.readFileSync('D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826/sealed_manifest_r13.json', 'utf8'));

const manifestOuterPaths = new Set(m.entries.map(e => e.path.split('!')[0]));
console.log('Manifest outer files:', manifestOuterPaths.size);
