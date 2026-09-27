const fs = require('fs');
const manifest = JSON.parse(fs.readFileSync('D:/ANTIGRAVITY_WORKSPACE/LGD_IMPORT_RUNTIME/sealed_manifest_r13.json', 'utf8'));

const physicalCount = manifest.entries.length;
const distinctHashes = new Set(manifest.entries.map(e => e.source_sha256)).size;
const logicalCount = manifest.entries.reduce((acc, e) => acc + e.logical_outputs.length, 0);

console.log('PHYSICAL_MANIFEST_ENTRY_COUNT: ' + physicalCount);
console.log('DISTINCT_PHYSICAL_SOURCE_COUNT: ' + distinctHashes);
console.log('LOGICAL_BATCH_COUNT: ' + logicalCount);

let entityCounts = {};
manifest.entries.forEach(e => {
    e.logical_outputs.forEach(lo => {
        entityCounts[lo] = (entityCounts[lo] || 0) + 1;
    });
});
console.log(entityCounts);
