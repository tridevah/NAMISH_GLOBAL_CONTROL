const fs = require('fs');
const crypto = require('crypto');

const manifestPath = 'D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826/sealed_manifest_r15.json';
const manifestBuffer = fs.readFileSync(manifestPath);
const manifestHash = crypto.createHash('sha256').update(manifestBuffer).digest('hex');
const manifest = JSON.parse(manifestBuffer);

const releaseId = crypto.randomUUID();
let sql = "BEGIN;\n";
sql += "INSERT INTO data_imports.releases (id, release_name, source_uri, sha256_hash, manifest_hash, status) VALUES ('" + releaseId + "', 'LGD_20260826_CORE_R15', 'INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826', '00', '" + manifestHash + "', 'EXTRACTING');\n\n";

let entrySql = "";
let outputSql = "";
let batchSql = "";

for (const entry of manifest.entries) {
    const entryId = crypto.randomUUID();
    entrySql += "INSERT INTO data_imports.release_manifest_entries (id, release_id, path, size, source_sha256, role, scope, entity_type) VALUES ('" + entryId + "', '" + releaseId + "', '" + entry.path + "', 0, '00', 'PHYSICAL', 'STATE', 'MULTIPLE');\n";
    
    for (const out of entry.logical_outputs) {
        const outId = crypto.randomUUID();
        const batchId = crypto.randomUUID();
        outputSql += "INSERT INTO data_imports.release_manifest_logical_outputs (id, release_id, manifest_entry_id, logical_entity) VALUES ('" + outId + "', '" + releaseId + "', '" + entryId + "', '" + out.logical_entity + "');\n";
        const logicalKey = entry.path + '!!' + out.logical_entity + '!' + out.ordinal;
        batchSql += "INSERT INTO data_imports.batches (id, release_id, manifest_logical_output_id, logical_batch_key, entity_type, status, total_records, successful_records, failed_records) VALUES ('" + batchId + "', '" + releaseId + "', '" + outId + "', '" + logicalKey + "', '" + out.logical_entity + "', 'PENDING', 0, 0, 0);\n";
    }
}

sql += entrySql + "\n" + outputSql + "\n" + batchSql + "\n";
sql += "COMMIT;\n";

fs.writeFileSync('D:/NAMISH_GLOBAL_CONTROL/scripts/register_r15_actual.sql', sql);
fs.writeFileSync('D:/NAMISH_GLOBAL_CONTROL/scripts/r15_release_id.txt', releaseId);
console.log("Release ID:", releaseId);
