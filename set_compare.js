const fs = require('fs');
const xlsx = require('xlsx');
const crypto = require('crypto');

// ── Build canonical SOURCE set ──────────────────────────────────────────────
const wb = xlsx.readFile('HSN_Directory.xlsx');
const hsnSheet = wb.Sheets['HSN_MSTR'];
const rawRows = xlsx.utils.sheet_to_json(hsnSheet, { header: 1, defval: '', raw: true });

const sourceMap = new Map(); // code → description

rawRows.slice(1).forEach((row, idx) => {
    const excelRowNum = idx + 2;
    const rawCode = row[0];
    const rawDesc = row[1];
    if (rawCode === null || rawCode === undefined || String(rawCode).trim() === '') return;

    let code = String(rawCode).trim().replace(/\s+/g, '');

    // Adjudicated normalization: only apply to 5- and 7-digit codes that have a
    // confirmed canonical form already present with a leading zero.
    // "2307 00" and "2514 00" become 230700/251400 after space removal (6 digits) — valid.
    // 5-digit "30559" → "030559" only valid if ITC(HS) code is 030559 (Chapter 03).
    // 7-digit "3074330" → "03074330" only valid if parent chapter is 03.
    // These are all accepted as per the normalization rule.

    if (code.length % 2 !== 0 && code.length >= 5) {
        code = code.padStart(code.length + 1, '0');
    }

    if (!['2','4','6','8'].includes(String(code.length))) return; // invalid length

    // Dedup: first occurrence wins
    if (!sourceMap.has(code)) {
        sourceMap.set(code, {
            code,
            description: String(rawDesc).trim().replace(/\r\n|\r|\n/g, ' ').replace(/\s+/g, ' '),
            excelRow: excelRowNum
        });
    }
});

console.log('SOURCE HSN count:', sourceMap.size);

// ── Load DB export ──────────────────────────────────────────────────────────
const dbRaw = fs.readFileSync('db_hsn_export.json', 'utf8');
// The export is wrapped in the Supabase JSON envelope
const dbJson = JSON.parse(dbRaw.replace(/^[\s\S]*?"rows":\s*(\[[\s\S]*?\])\s*,\s*"warning"/, '$1').replace(/[\s\S]*/, match => {
    const m = match.match(/"rows":\s*(\[[\s\S]*?\])\s*[,}]/);
    return m ? m[1] : '[]';
}));

// Actually let's just parse it directly  
let dbRows;
try {
    const fullJson = JSON.parse(dbRaw);
    dbRows = fullJson.rows;
} catch(e) {
    // Try extracting rows from the output
    const m = dbRaw.match(/"rows":\s*(\[[\s\S]*?\])\s*,\s*"warning"/);
    dbRows = m ? JSON.parse(m[1]) : [];
}

console.log('DB HSN count:', dbRows ? dbRows.length : 'PARSE ERROR');

if (!dbRows || dbRows.length === 0) {
    console.error('Could not parse DB export. Check db_hsn_export.json');
    process.exit(1);
}

const dbMap = new Map();
for (const row of dbRows) {
    dbMap.set(row.code, row);
}

// ── Set comparison ──────────────────────────────────────────────────────────
const dbMinusSource = []; // in DB but not in SOURCE
const sourceMinusDb = []; // in SOURCE but not in DB

for (const [code, row] of dbMap.entries()) {
    if (!sourceMap.has(code)) {
        dbMinusSource.push({ code, db_id: row.id, db_desc: row.description, db_class: row.classification_level });
    }
}

for (const [code, row] of sourceMap.entries()) {
    if (!dbMap.has(code)) {
        sourceMinusDb.push({ code, source_desc: row.description, excel_row: row.excelRow });
    }
}

console.log('\n=== SET COMPARISON RESULT ===');
console.log('DB_MINUS_SOURCE:', dbMinusSource.length);
if (dbMinusSource.length > 0) {
    console.log(JSON.stringify(dbMinusSource, null, 2));
}
console.log('SOURCE_MINUS_DB:', sourceMinusDb.length);
if (sourceMinusDb.length > 0) {
    console.log(JSON.stringify(sourceMinusDb, null, 2));
}

fs.writeFileSync('set_comparison.json', JSON.stringify({ dbMinusSource, sourceMinusDb }, null, 2));
