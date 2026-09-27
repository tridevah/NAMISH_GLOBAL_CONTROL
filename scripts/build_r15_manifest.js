const fs = require('fs');
const path = require('path');

const SRC = 'D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826';
const states = fs.readdirSync(SRC).filter(d => fs.statSync(path.join(SRC, d)).isDirectory());

let manifest = {
    release_id: "R15",
    version: "1.0",
    description: "Core Geography Master",
    entries: []
};

for (const state of states) {
    const stateDir = path.join(SRC, state);
    const zips = fs.readdirSync(stateDir).filter(f => f.endsWith('.zip'));
    if (zips.length === 0) continue;
    
    let targetZip = zips[0];
    if (state === 'ARUNACHAL PRADESH') {
        targetZip = 'ARUNACHAL_PRADESH_CORE_FIXED.zip';
    }
    
    // 1. STATE & DISTRICT from districtofSpecificState
    manifest.entries.push({
        path: state + '/' + targetZip + '!districtofSpecificState.xlsx', // just a logical path pattern since filenames have timestamps
        type: 'LGD_EXCEL_XML',
        logical_outputs: [
            { logical_entity: 'STATE', ordinal: 0 },
            { logical_entity: 'DISTRICT', ordinal: 1 }
        ]
    });
    
    // 2. SUB_DISTRICT
    manifest.entries.push({
        path: state + '/' + targetZip + '!subDistrictofSpecificState.xlsx',
        type: 'LGD_EXCEL_XML',
        logical_outputs: [
            { logical_entity: 'SUB_DISTRICT', ordinal: 0 }
        ]
    });
    
    // 3. BLOCK
    manifest.entries.push({
        path: state + '/' + targetZip + '!blockofspecificState.xlsx',
        type: 'LGD_EXCEL_XML',
        logical_outputs: [
            { logical_entity: 'BLOCK', ordinal: 0 }
        ]
    });
}

fs.writeFileSync('D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826/sealed_manifest_r15.json', JSON.stringify(manifest, null, 2));
console.log("R15 manifest created with", manifest.entries.length, "entries");
