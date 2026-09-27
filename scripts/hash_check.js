const fs = require('fs');
const crypto = require('crypto');

function h(path) {
    if (!fs.existsSync(path)) return 'MISSING';
    return crypto.createHash('sha256').update(fs.readFileSync(path)).digest('hex');
}

console.log('lgd_import_r7.js: ' + h('scripts/lgd_import_r7.js'));
console.log('lgd_import_r7_physical.js: ' + h('scripts/lgd_import_r7_physical.js'));
console.log('sealed_manifest_r6.json: ' + h('D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826/sealed_manifest_r6.json'));
console.log('package-lock.json: ' + h('package-lock.json'));
console.log('000021_batches_reconciliation_columns.sql: ' + h('supabase/migrations/20260827000021_batches_reconciliation_columns.sql'));
console.log('000022_geography_identity_correction.sql: ' + h('supabase/migrations/20260827000022_geography_identity_correction.sql'));
