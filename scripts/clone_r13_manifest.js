const fs = require('fs');
const m = JSON.parse(fs.readFileSync('D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826/sealed_manifest_r6.json', 'utf8'));

m.release_name = 'LGD_20260826_CORE_R13';
m.created_at = new Date().toISOString();

for (let e of m.entries) {
    if (e.path.includes('Pincodeto_Village_Mapping')) {
        e.logical_outputs = ['PIN_VILLAGE'];
    }
    if (e.path.includes('Pincodeto_Urban_Mapping')) {
        e.logical_outputs = ['PIN_URBAN_LOCAL_BODY'];
    }
}

fs.writeFileSync('D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826/sealed_manifest_r13.json', JSON.stringify(m, null, 2));
console.log('R13 manifest created.');
