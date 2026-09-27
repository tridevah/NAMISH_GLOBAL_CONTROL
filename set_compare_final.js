const fs = require('fs');
const xlsx = require('xlsx');

// ── Build canonical SOURCE set for HSN ───────────────────────────────────────
const wb = xlsx.readFile('HSN_Directory.xlsx');
const hsnSheet = wb.Sheets['HSN_MSTR'];
const hsnRawRows = xlsx.utils.sheet_to_json(hsnSheet, { header: 1, defval: '', raw: true });

const sourceHsnMap = new Map(); 

hsnRawRows.slice(1).forEach((row, idx) => {
    const rawCode = row[0];
    if (rawCode === null || rawCode === undefined || String(rawCode).trim() === '') return;

    let code = String(rawCode).trim().replace(/\s+/g, '');

    if (code.length % 2 !== 0 && code.length >= 5) {
        code = code.padStart(code.length + 1, '0');
    }

    if (!['2','4','6','8'].includes(String(code.length))) return; 

    // Dedup: first occurrence wins
    if (!sourceHsnMap.has(code)) {
        sourceHsnMap.set(code, { code });
    }
});
console.log('SOURCE HSN count:', sourceHsnMap.size);

// ── Build canonical SOURCE set for SAC ───────────────────────────────────────
const sacSheet = wb.Sheets['SAC_MSTR'];
const sacRawRows = xlsx.utils.sheet_to_json(sacSheet, { header: 1, defval: '', raw: true });

const sourceSacMap = new Map(); 

sacRawRows.slice(1).forEach((row, idx) => {
    const rawCode = row[0];
    if (rawCode === null || rawCode === undefined || String(rawCode).trim() === '') return;

    let code = String(rawCode).trim().replace(/\s+/g, '');
    if (!['2','4','6'].includes(String(code.length))) return; 
    
    // Apply 12/2023 amendment exclusions
    if (code === '999692' || code === '999694') return;

    if (!sourceSacMap.has(code)) {
        sourceSacMap.set(code, { code });
    }
});
console.log('SOURCE SAC count:', sourceSacMap.size);

// ── Load DB exports ──────────────────────────────────────────────────────────
function parseDbExport(filename) {
    const dbRaw = fs.readFileSync(filename, 'utf8');
    let dbRows;
    try {
        dbRows = JSON.parse(dbRaw).rows;
    } catch(e) {
        const m = dbRaw.match(/"rows":\s*(\[[\s\S]*?\])\s*,\s*"warning"/);
        dbRows = m ? JSON.parse(m[1]) : [];
    }
    return dbRows || [];
}

const dbHsnRows = parseDbExport('db_hsn_export.json');
const dbSacRows = parseDbExport('db_sac_export.json');

console.log('DB HSN count:', dbHsnRows.length);
console.log('DB SAC count:', dbSacRows.length);

const dbHsnMap = new Map(dbHsnRows.map(r => [r.code, r]));
const dbSacMap = new Map(dbSacRows.map(r => [r.code, r]));

// ── Set comparison ──────────────────────────────────────────────────────────
const dbMinusSourceHsn = [];
const sourceMinusDbHsn = [];
const dbMinusSourceSac = [];
const sourceMinusDbSac = [];

for (const code of dbHsnMap.keys()) {
    if (!sourceHsnMap.has(code)) dbMinusSourceHsn.push(code);
}
for (const code of sourceHsnMap.keys()) {
    if (!dbHsnMap.has(code)) sourceMinusDbHsn.push(code);
}

for (const code of dbSacMap.keys()) {
    if (!sourceSacMap.has(code)) dbMinusSourceSac.push(code);
}
for (const code of sourceSacMap.keys()) {
    if (!dbSacMap.has(code)) sourceMinusDbSac.push(code);
}

console.log('\n=== EXACT SET COMPARISON ===');
console.log('HSN_DB_MINUS_SOURCE:', dbMinusSourceHsn.length);
console.log('HSN_SOURCE_MINUS_DB:', sourceMinusDbHsn.length);
console.log('SAC_DB_MINUS_SOURCE:', dbMinusSourceSac.length);
console.log('SAC_SOURCE_MINUS_DB:', sourceMinusDbSac.length);

if (dbMinusSourceHsn.length > 0) console.log('HSN Extra in DB:', dbMinusSourceHsn);
if (sourceMinusDbHsn.length > 0) console.log('HSN Missing in DB:', sourceMinusDbHsn);
if (dbMinusSourceSac.length > 0) console.log('SAC Extra in DB:', dbMinusSourceSac);
if (sourceMinusDbSac.length > 0) console.log('SAC Missing in DB:', sourceMinusDbSac);
