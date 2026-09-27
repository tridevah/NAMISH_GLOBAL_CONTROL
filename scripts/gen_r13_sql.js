const fs = require('fs');
const crypto = require('crypto');
const m = JSON.parse(fs.readFileSync('D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826/sealed_manifest_r13.json', 'utf8'));

let sql = 'BEGIN;\n';
const v_r13_id = 'b1300000-0000-0000-0000-000000000000'; // deterministic R13 UUID
sql += "INSERT INTO data_imports.releases (id, release_name, status, source_uri, sha256_hash) VALUES ('" + v_r13_id + "', 'LGD_20260826_CORE_R13', 'EXTRACTING', 'file://D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826', 'DIRECTORY_HASH');\n";

for (const entry of m.entries) {
    let safePath = entry.path.replace(/'/g, "''");
    const entryId = crypto.createHash('md5').update('ENTRY' + entry.path).digest('hex');
    const entryUuid = [entryId.slice(0,8), entryId.slice(8,12), entryId.slice(12,16), entryId.slice(16,20), entryId.slice(20,32)].join('-');

    sql += "INSERT INTO data_imports.release_manifest_entries (id, release_id, path, size, source_sha256, role, scope, entity_type) VALUES ('" + entryUuid + "', '" + v_r13_id + "', '" + safePath + "', " + entry.size + ", '" + entry.source_sha256 + "', '" + entry.role + "', '" + entry.scope + "', 'UNKNOWN');\n";
    
    for (let i = 0; i < entry.logical_outputs.length; i++) {
        const lo = entry.logical_outputs[i];
        const loId = crypto.createHash('md5').update('LO' + entry.path + lo + i).digest('hex');
        const loUuid = [loId.slice(0,8), loId.slice(8,12), loId.slice(12,16), loId.slice(16,20), loId.slice(20,32)].join('-');
        
        sql += "INSERT INTO data_imports.release_manifest_logical_outputs (id, release_id, manifest_entry_id, logical_entity) VALUES ('" + loUuid + "', '" + v_r13_id + "', '" + entryUuid + "', '" + lo + "');\n";
        
        const logicalKey = safePath + '!!' + lo + '!' + i;
        sql += "INSERT INTO data_imports.batches (release_id, manifest_logical_output_id, logical_batch_key, entity_type, source_path, status) VALUES ('" + v_r13_id + "', '" + loUuid + "', '" + logicalKey + "', '" + lo + "', '" + safePath + "', 'PENDING');\n";
    }
}
sql += "COMMIT;\n";
fs.writeFileSync('D:/NAMISH_GLOBAL_CONTROL/scripts/register_r13.sql', sql);
