const fs = require('fs');
const crypto = require('crypto');

function hashFile(path) {
    const data = fs.readFileSync(path);
    return crypto.createHash('sha256').update(data).digest('hex');
}

const hsnSourceRaw = fs.readFileSync('normalized_hsn_source.json', 'utf8').trim().split('\n').map(JSON.parse);
const hsnDbRaw = JSON.parse(fs.readFileSync('db_hsn_export.json', 'utf8'));
const sacSourceRaw = fs.readFileSync('normalized_sac_source.json', 'utf8').trim().split('\n').map(JSON.parse);
const sacDbRaw = JSON.parse(fs.readFileSync('db_sac_export.json', 'utf8'));

const hsnSrcMap = new Map(hsnSourceRaw.map(r => [r.code, r]));
const hsnDbMap = new Map(hsnDbRaw.map(r => [r.code, r]));

const sacSrcMap = new Map(sacSourceRaw.map(r => [r.code, r]));
const sacDbMap = new Map(sacDbRaw.map(r => [r.code, r]));

let hsnDbMinusSource = 0;
let hsnSourceMinusDb = 0;
let hsnDescMismatches = 0;

let sacDbMinusSource = 0;
let sacSourceMinusDb = 0;
let sacDescMismatches = 0;

const affectedRows = [];

for (const [code, dbRow] of hsnDbMap.entries()) {
    const srcRow = hsnSrcMap.get(code);
    if (!srcRow) {
        hsnDbMinusSource++;
        affectedRows.push({ type: 'HSN_DB_EXTRA', code });
    } else {
        if (dbRow.description !== srcRow.description || dbRow.parent_code !== srcRow.parent_code || dbRow.classification_level !== srcRow.classification_level) {
            hsnDescMismatches++;
            affectedRows.push({ type: 'HSN_MISMATCH', code, db: dbRow, src: srcRow });
        }
    }
}
for (const code of hsnSrcMap.keys()) {
    if (!hsnDbMap.has(code)) {
        hsnSourceMinusDb++;
        affectedRows.push({ type: 'HSN_SOURCE_EXTRA', code });
    }
}

for (const [code, dbRow] of sacDbMap.entries()) {
    const srcRow = sacSrcMap.get(code);
    if (!srcRow) {
        sacDbMinusSource++;
        affectedRows.push({ type: 'SAC_DB_EXTRA', code });
    } else {
        if (dbRow.description !== srcRow.description || dbRow.parent_code !== srcRow.parent_code || dbRow.classification_level !== srcRow.classification_level) {
            sacDescMismatches++;
            affectedRows.push({ type: 'SAC_MISMATCH', code, db: dbRow, src: srcRow });
        }
    }
}
for (const code of sacSrcMap.keys()) {
    if (!sacDbMap.has(code)) {
        sacSourceMinusDb++;
        affectedRows.push({ type: 'SAC_SOURCE_EXTRA', code });
    }
}

const manifest = {
    hsn_source: {
        raw_url: 'https://tutorial.gst.gov.in/downloads/HSN_SAC.xlsx',
        raw_sha256: '051108e31063f1ef0d6dfb005a622bcc848878fa2d94fae51a73e67f8916871e',
        download_timestamp: '2026-09-04T17:08:00Z',
        normalized_sha256: hashFile('normalized_hsn_source.json'),
        db_export_sha256: hashFile('db_hsn_export.json'),
        row_count: hsnSourceRaw.length
    },
    sac_source: {
        raw_url: 'https://tutorial.gst.gov.in/downloads/HSN_SAC.xlsx',
        raw_sha256: '051108e31063f1ef0d6dfb005a622bcc848878fa2d94fae51a73e67f8916871e',
        download_timestamp: '2026-09-04T17:08:00Z',
        normalized_sha256: hashFile('normalized_sac_source.json'),
        db_export_sha256: hashFile('db_sac_export.json'),
        row_count: sacSourceRaw.length
    },
    parser: 'Node.js custom deterministic',
    version: '1.0',
    comparison_results: {
        HSN_CODE_DB_MINUS_SOURCE: hsnDbMinusSource,
        HSN_CODE_SOURCE_MINUS_DB: hsnSourceMinusDb,
        HSN_DESCRIPTION_MISMATCHES: hsnDescMismatches,
        HSN_FULL_TUPLE_DB_MINUS_SOURCE: hsnDbMinusSource + hsnDescMismatches,
        HSN_FULL_TUPLE_SOURCE_MINUS_DB: hsnSourceMinusDb + hsnDescMismatches,
        SAC_DB_MINUS_LEGAL_SOURCE: sacDbMinusSource,
        SAC_LEGAL_SOURCE_MINUS_DB: sacSourceMinusDb,
        SAC_DESCRIPTION_MISMATCHES: sacDescMismatches
    },
    affectedRows: affectedRows.slice(0, 50)
};

fs.writeFileSync('source_closure_manifest.json', JSON.stringify(manifest, null, 2));
console.log('Manifest written. Mismatches:', hsnDescMismatches + sacDescMismatches);
