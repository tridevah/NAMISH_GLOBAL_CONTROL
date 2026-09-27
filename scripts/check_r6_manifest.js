const fs = require('fs');
const path = require('path');

const m = JSON.parse(fs.readFileSync('D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826/sealed_manifest_r6.json', 'utf8'));

console.log('Total entries:', m.entries.length);
console.log('Distinct SHA256:', new Set(m.entries.map(e => e.source_sha256)).size);

let entityCounts = {};
m.entries.forEach(e => {
    e.logical_outputs.forEach(lo => {
        entityCounts[lo] = (entityCounts[lo] || 0) + 1;
    });
});
console.log(entityCounts);

let pincodeEntries = m.entries.filter(e => e.path.includes('Pincode'));
console.log('PINCODE FILES:', pincodeEntries.map(e => e.path + ' -> ' + e.logical_outputs.join(',')));
