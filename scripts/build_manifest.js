const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const yauzl = require('yauzl');

const SOURCE_DIR = 'D:\\ANTIGRAVITY_WORKSPACE\\INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826';
const MANIFEST_PATH = path.join(SOURCE_DIR, 'sealed_manifest.json');

function hashFile(filePath) {
    return new Promise((resolve) => {
        const hash = crypto.createHash('sha256');
        const stream = fs.createReadStream(filePath);
        stream.on('data', data => hash.update(data));
        stream.on('end', () => resolve(hash.digest('hex')));
    });
}

function getRole(filename) {
    const f = filename.toLowerCase();
    if (f.includes('localities_urban')) return 'OFFICIAL_EMPTY';
    if (f.includes('electoral') || f.includes('parliament') || f.includes('assembly')) return 'DEFERRED';
    if (f.includes('all_')) return 'VALIDATION_ONLY'; // The All-India files
    return 'IMPORT_AUTHORITY'; // The individual state files inside zips
}

async function build() {
    let manifest = {
        generated_at: new Date().toISOString(),
        entries: []
    };

    const items = fs.readdirSync(SOURCE_DIR);
    for (const stateName of items) {
        const statePath = path.join(SOURCE_DIR, stateName);
        if (fs.statSync(statePath).isDirectory()) {
            const files = fs.readdirSync(statePath);
            for (const file of files) {
                const filePath = path.join(statePath, file);
                const role = getRole(file);
                const size = fs.statSync(filePath).size;
                const sha = await hashFile(filePath);
                
                if (file.endsWith('.zip')) {
                    // Inspect internal contents
                    await new Promise((resolve) => {
                        yauzl.open(filePath, { lazyEntries: true }, (err, zipfile) => {
                            if(err) return resolve();
                            zipfile.readEntry();
                            zipfile.on('entry', (entry) => {
                                manifest.entries.push({
                                    path: `${stateName}/${file}!${entry.fileName}`,
                                    size: entry.uncompressedSize,
                                    source_sha256: sha,
                                    role: getRole(entry.fileName),
                                    scope: stateName,
                                    entity: 'derived_from_filename'
                                });
                                zipfile.readEntry();
                            });
                            zipfile.on('end', resolve);
                        });
                    });
                } else {
                    manifest.entries.push({
                        path: `${stateName}/${file}`,
                        size: size,
                        source_sha256: sha,
                        role: role,
                        scope: stateName,
                        entity: 'derived_from_filename'
                    });
                }
            }
        } else {
            // Root level files
            manifest.entries.push({
                path: stateName,
                size: fs.statSync(statePath).size,
                source_sha256: await hashFile(statePath),
                role: getRole(stateName),
                scope: 'ALL_INDIA',
                entity: 'derived_from_filename'
            });
        }
    }

    // Canonically sort
    manifest.entries.sort((a,b) => a.path.localeCompare(b.path));
    
    const manifestString = JSON.stringify(manifest);
    const manifestHash = crypto.createHash('sha256').update(manifestString).digest('hex');
    manifest.manifest_sha256 = manifestHash;
    
    fs.writeFileSync(MANIFEST_PATH, JSON.stringify(manifest, null, 2));
    console.log(`Manifest created with hash: ${manifestHash}. Total entries: ${manifest.entries.length}`);
}
build().catch(console.error);
