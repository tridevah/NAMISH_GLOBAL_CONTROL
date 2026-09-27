const fs = require('fs');
const path = require('path');

const r13 = require('D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826/sealed_manifest_r13.json');

let r15 = {
    release_id: "R15",
    version: "1.0",
    description: "Core Geography Master",
    entries: []
};

// Map of real paths
let realPaths = { district: {}, subdistrict: {}, block: {} };

for (let e of r13.entries) {
    if (e.path.includes('ARUNACHAL')) continue; // Skip bad Arunachal
    let state = e.path.split('/')[0];
    if (e.path.includes('districtofSpecific')) realPaths.district[state] = e.path;
    if (e.path.includes('subDistrictofSpecific')) realPaths.subdistrict[state] = e.path;
    if (e.path.includes('blockofspecific')) realPaths.block[state] = e.path;
}

const SRC = 'D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826';
const states = fs.readdirSync(SRC).filter(d => fs.statSync(path.join(SRC, d)).isDirectory());

for (const state of states) {
    if (state === 'ARUNACHAL PRADESH') {
        r15.entries.push({
            path: 'ARUNACHAL PRADESH/ARUNACHAL_PRADESH_CORE_FIXED.zip!districtofSpecificState.xlsx',
            type: 'LGD_EXCEL_XML',
            logical_outputs: [ { logical_entity: 'STATE', ordinal: 0 }, { logical_entity: 'DISTRICT', ordinal: 1 } ]
        });
        r15.entries.push({
            path: 'ARUNACHAL PRADESH/ARUNACHAL_PRADESH_CORE_FIXED.zip!subDistrictofSpecificState.xlsx',
            type: 'LGD_EXCEL_XML',
            logical_outputs: [ { logical_entity: 'SUB_DISTRICT', ordinal: 0 } ]
        });
        r15.entries.push({
            path: 'ARUNACHAL PRADESH/ARUNACHAL_PRADESH_CORE_FIXED.zip!blockofspecificState.xlsx',
            type: 'LGD_EXCEL_XML',
            logical_outputs: [ { logical_entity: 'BLOCK', ordinal: 0 } ]
        });
    } else {
        r15.entries.push({
            path: realPaths.district[state],
            type: 'LGD_EXCEL_XML',
            logical_outputs: [ { logical_entity: 'STATE', ordinal: 0 }, { logical_entity: 'DISTRICT', ordinal: 1 } ]
        });
        r15.entries.push({
            path: realPaths.subdistrict[state],
            type: 'LGD_EXCEL_XML',
            logical_outputs: [ { logical_entity: 'SUB_DISTRICT', ordinal: 0 } ]
        });
        r15.entries.push({
            path: realPaths.block[state],
            type: 'LGD_EXCEL_XML',
            logical_outputs: [ { logical_entity: 'BLOCK', ordinal: 0 } ]
        });
    }
}

fs.writeFileSync('D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826/sealed_manifest_r15.json', JSON.stringify(r15, null, 2));
let batches = 0;
r15.entries.forEach(e => batches += e.logical_outputs.length);
console.log("R15 manifest created with", r15.entries.length, "entries and", batches, "logical batches.");
