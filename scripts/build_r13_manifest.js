const fs = require('fs');
const crypto = require('crypto');
const yauzl = require('yauzl');
const path = require('path');

const SRC = 'D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826';

let manifest = {
    release_name: 'LGD_20260826_CORE_R13',
    created_at: new Date().toISOString(),
    entries: [] // Physical entries, containing logical outputs
};

const getHash = (filePath) => {
    return new Promise((resolve) => {
        const hash = crypto.createHash('sha256');
        const s = fs.createReadStream(filePath);
        s.on('data', d => hash.update(d));
        s.on('end', () => resolve(hash.digest('hex')));
    });
};

function getLogicalEntities(fileName) {
    if (fileName.includes('district')) return ['DISTRICT'];
    if (fileName.includes('subdistrict')) return ['SUB_DISTRICT'];
    if (fileName.includes('village') && !fileName.includes('LocalBody') && !fileName.includes('Block') && !fileName.includes('pri')) return ['VILLAGE'];
    if (fileName.includes('block') && !fileName.includes('Village')) return ['BLOCK'];
    if (fileName.includes('blockVillage')) return ['BLOCK_VILLAGE'];
    if (fileName.includes('priLbSpecific')) return ['PRI_DISTRICT', 'PRI_INTERMEDIATE', 'GRAM_PANCHAYAT'];
    if (fileName.includes('ulbSpecific')) return ['URBAN_LOCAL_BODY'];
    if (fileName.includes('tlbSpecific')) return ['TRADITIONAL_LOCAL_BODY'];
    if (fileName.includes('lbSpecificVillage')) return ['LOCAL_BODY_VILLAGE'];
    if (fileName.includes('urbanWard')) return ['URBAN_WARD'];
    if (fileName.includes('priWard')) return ['PRI_WARD'];
    if (fileName.includes('wardCoverage')) return ['WARD_COVERAGE'];
    if (fileName === 'PIN CODE.csv') return ['PINCODE', 'POST_OFFICE'];
    if (fileName === 'Pincodeto_Village_Mapping_2026-08-26_23-05-48.xlsx') return ['PIN_VILLAGE'];
    if (fileName === 'Pincodeto_Urban_Mapping_2026-08-26_23-06-09.xlsx') return ['PIN_URBAN_LOCAL_BODY'];
    return [];
}

async function run() {
    const states = fs.readdirSync(SRC).filter(d => fs.statSync(path.join(SRC, d)).isDirectory());
    for (const state of states) {
        const stateDir = path.join(SRC, state);
        const files = fs.readdirSync(stateDir).filter(f => f.endsWith('.zip') || f.endsWith('.xlsx') || f.endsWith('.csv'));
        for (const file of files) {
            const fullPath = path.join(stateDir, file);
            const sha256 = await getHash(fullPath);
            const size = fs.statSync(fullPath).size;
            
            let entry = {
                path: file,
                size: size,
                source_sha256: sha256,
                role: 'PHYSICAL_SOURCE',
                scope: state,
                logical_outputs: []
            };

            if (file.endsWith('.zip')) {
                const z = await new Promise((res, rej) => yauzl.open(fullPath, {lazyEntries:true}, (err, zf) => {
                    if (err) return res(null);
                    let internals = [];
                    zf.readEntry();
                    zf.on('entry', e => { internals.push(e.fileName); zf.readEntry(); });
                    zf.on('end', () => res(internals));
                }));
                if (z && z.length === 1) {
                    entry.path = file + '!' + z[0];
                    entry.logical_outputs = getLogicalEntities(z[0]);
                }
            } else {
                entry.logical_outputs = getLogicalEntities(file);
                if (file.includes('PIN CODE')) entry.scope = 'ALL_INDIA';
                if (file.includes('Pincodeto')) entry.scope = 'ALL_INDIA';
            }
            manifest.entries.push(entry);
        }
    }
    
    // sort for determinism
    manifest.entries.sort((a,b) => (a.scope+a.path).localeCompare(b.scope+b.path));
    fs.writeFileSync('D:/ANTIGRAVITY_WORKSPACE/LGD_IMPORT_RUNTIME/sealed_manifest_r13.json', JSON.stringify(manifest, null, 2));
    console.log('Manifest written.');
}
run();
