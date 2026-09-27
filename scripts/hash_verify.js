const fs = require('fs');
const crypto = require('crypto');
const { execSync } = require('child_process');

const res = execSync('docker exec supabase_db_NAMISH_GLOBAL_CONTROL psql -U postgres -t -c "SELECT path, source_sha256 FROM data_imports.release_manifest_entries WHERE release_id = \'b3573f9b-1eff-47d5-8cdf-fba3eba74b19\';"', { encoding: 'utf8' });

let allMatch = true;
const lines = res.split('\n').map(l => l.trim()).filter(l => l);
const checked = new Set();
for (const line of lines) {
    const parts = line.split('|').map(s => s.trim());
    if (parts.length === 2) {
        const physicalPath = parts[0].split('!')[0];
        if (checked.has(physicalPath)) continue;
        checked.add(physicalPath);
        
        const p = 'D:/NAMISH_GLOBAL_CONTROL/india_geography_manual_download_20260826/' + physicalPath;
        if (fs.existsSync(p)) {
            const hash = crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
            if (hash !== parts[1]) {
                console.log('Mismatch: ' + physicalPath + ' - Expected ' + parts[1] + ', got ' + hash);
                allMatch = false;
            }
        } else {
            console.log('Missing: ' + p);
            allMatch = false;
        }
    }
}
if (allMatch) console.log("ALL PHYSICAL HASHES MATCH EXACTLY");
