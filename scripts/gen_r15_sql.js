const fs = require('fs');
const crypto = require('crypto');

const manifestPath = 'D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826/sealed_manifest_r15.json';
const manifestBuffer = fs.readFileSync(manifestPath);
const manifestHash = crypto.createHash('sha256').update(manifestBuffer).digest('hex');
const manifest = JSON.parse(manifestBuffer);

const releaseId = crypto.randomUUID();
let sql = "BEGIN;\n";
sql += INSERT INTO data_imports.releases (id, description, status) VALUES ('', 'R15 Core Geography Staging', 'EXTRACTING');\n\n;

// Insert manifest
sql += INSERT INTO data_imports.release_manifest_metadata (release_id, sealed_manifest_sha256, version) VALUES ('', '', '1.0');\n\n;

let entrySql = "";
let outputSql = "";
let batchSql = "";

let entryIndex = 1;
for (const entry of manifest.entries) {
    const entryId = crypto.randomUUID();
    entrySql += INSERT INTO data_imports.release_manifest_entries (id, release_id, path, type) VALUES ('', '', '', '');\n;
    
    for (const out of entry.logical_outputs) {
        const outId = crypto.randomUUID();
        const batchId = crypto.randomUUID();
        outputSql += INSERT INTO data_imports.release_manifest_logical_outputs (id, manifest_entry_id, logical_entity, ordinal) VALUES ('', '', '', );\n;
        batchSql += INSERT INTO data_imports.batches (id, release_id, logical_output_id, status) VALUES ('', '', '', 'PENDING');\n;
    }
}

sql += entrySql + "\n" + outputSql + "\n" + batchSql + "\n";
sql += "COMMIT;\n";

fs.writeFileSync('D:/NAMISH_GLOBAL_CONTROL/scripts/register_r15.sql', sql);
fs.writeFileSync('D:/NAMISH_GLOBAL_CONTROL/scripts/r15_release_id.txt', releaseId);
console.log("Release ID:", releaseId);
console.log("Manifest Hash:", manifestHash);
