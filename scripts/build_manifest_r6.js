const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const yauzl = require('yauzl');

const SOURCE_DIR = 'D:\\ANTIGRAVITY_WORKSPACE\\INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826';

function hashFile(fp) {
    return new Promise(res => {
        const h = crypto.createHash('sha256');
        fs.createReadStream(fp).on('data', d => h.update(d)).on('end', () => res(h.digest('hex')));
    });
}

const LOGICAL_OUTPUT_MAP = {
    'allblockstatewithcoveredvillage': ['BLOCK_VILLAGE'],
    'villagegrampanchayatmapping':     ['LOCAL_BODY_VILLAGE'],
    'ulbwardforstatewithcov':          ['WARD_COVERAGE'],
    'ulbwardforstate':                 ['URBAN_WARD'],
    'priwards':                        ['PRI_WARD'],
    'prilbspecificstate':              ['PRI_DISTRICT','PRI_INTERMEDIATE','GRAM_PANCHAYAT'],
    'ulbspecificstate':                ['URBAN_LOCAL_BODY'],
    'tlbspecificstate':                ['TRADITIONAL_LOCAL_BODY'],
    'blockofspecificstate':            ['BLOCK'],
    'subdistrictofspecificstate':      ['SUB_DISTRICT'],
    'districtofspecificstate':         ['DISTRICT'],
    'villageofspecificstate':          ['VILLAGE'],
    'pincodecsv':                      ['PINCODE','POST_OFFICE'],
    'pincodetovillagemapping':         ['PIN_VILLAGE'],
    'pincodetourbanmapping':           ['PIN_URBAN_LOCAL_BODY']
};

function classify(filename) {
    const f = filename.toLowerCase().replace(/[^a-z_]/g,'');
    // Strict longest-match first (ulbwardforstatewithcov before ulbwardforstate)
    const ordered = [
        'ulbwardforstatewithcov', 'allblockstatewithcoveredvillage',
        'villagegrampanchayatmapping', 'ulbwardforstate', 'priwards',
        'prilbspecificstate', 'ulbspecificstate', 'tlbspecificstate',
        'blockofspecificstate', 'subdistrictofspecificstate',
        'districtofspecificstate', 'villageofspecificstate',
        'pincodecsv', 'pincodetovillagemapping', 'pincodetourbanmapping'
    ];
    for (const k of ordered) {
        if (f.includes(k)) return LOGICAL_OUTPUT_MAP[k];
    }
    return [];
}

async function build() {
    const manifest = { generated_at: new Date().toISOString(), identity_version: 'DOP_PIN_CSV_V1', entries: [] };

    const items = fs.readdirSync(SOURCE_DIR);
    for (const stateName of items) {
        const statePath = path.join(SOURCE_DIR, stateName);
        if (stateName.endsWith('.json')) continue;

        if (fs.statSync(statePath).isDirectory()) {
            for (const file of fs.readdirSync(statePath)) {
                const fp = path.join(statePath, file);
                const sha = await hashFile(fp);
                const size = fs.statSync(fp).size;
                const fl = file.toLowerCase();
                let role = 'IMPORT_AUTHORITY';
                if (fl.includes('localities_urban')) role = 'OFFICIAL_EMPTY';
                else if (fl.includes('electoral') || fl.includes('parliament')) role = 'DEFERRED';

                if (file.endsWith('.zip')) {
                    await new Promise(res => {
                        yauzl.open(fp, { lazyEntries: true }, (err, zf) => {
                            if (err) return res();
                            zf.readEntry();
                            zf.on('entry', entry => {
                                const lo = classify(entry.fileName);
                                const ef = entry.fileName.toLowerCase();
                                let er = 'IMPORT_AUTHORITY';
                                if (ef.includes('localities_urban')) er = 'OFFICIAL_EMPTY';
                                manifest.entries.push({
                                    path: `${stateName}/${file}!${entry.fileName}`,
                                    size: entry.uncompressedSize,
                                    source_sha256: sha,
                                    role: er, scope: stateName,
                                    logical_outputs: lo
                                });
                                zf.readEntry();
                            });
                            zf.on('end', res);
                        });
                    });
                } else {
                    manifest.entries.push({
                        path: `${stateName}/${file}`,
                        size, source_sha256: sha, role,
                        scope: stateName,
                        logical_outputs: classify(file)
                    });
                }
            }
        } else {
            const sha = await hashFile(statePath);
            const size = fs.statSync(statePath).size;
            const fl = stateName.toLowerCase();
            let role = 'IMPORT_AUTHORITY';
            if (fl.includes('all_')) role = 'VALIDATION_ONLY';
            manifest.entries.push({
                path: stateName, size, source_sha256: sha,
                role, scope: 'ALL_INDIA',
                logical_outputs: classify(stateName)
            });
        }
    }

    manifest.entries.sort((a,b) => a.path.localeCompare(b.path));
    const mStr = JSON.stringify(manifest);
    manifest.manifest_sha256 = crypto.createHash('sha256').update(mStr).digest('hex');

    const lo_count = manifest.entries.reduce((s,e) => s + (e.logical_outputs||[]).length, 0);
    fs.writeFileSync(path.join(SOURCE_DIR, 'sealed_manifest_r6.json'), JSON.stringify(manifest, null, 2));
    console.log(`R6 manifest: ${manifest.manifest_sha256}  physical=${manifest.entries.length}  logical=${lo_count}`);
}
build().catch(console.error);
