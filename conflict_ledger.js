const fs = require('fs');
const xlsx = require('xlsx');
const crypto = require('crypto');

const wb = xlsx.readFile('HSN_Directory.xlsx');
const hsnSheet = wb.Sheets['HSN_MSTR'];
const rawRows = xlsx.utils.sheet_to_json(hsnSheet, { header: 1, defval: '', raw: true });

// Skip header row
const dataRows = rawRows.slice(1);

const CONFLICT_ROWS = new Set([6592, 6601, 8951, 10512, 20559, 3193, 3394]); // 1-indexed data rows (Excel row = idx+2)

let report = [];

// Build map of normalized codes
const normalized = new Map();

dataRows.forEach((row, idx) => {
    const excelRowNum = idx + 2; // 1-indexed excel row
    const rawCode = row[0];
    const rawDesc = row[1];
    
    const rawCodeStr = String(rawCode === null || rawCode === undefined ? '' : rawCode).trim();
    const rawDescStr = String(rawDesc === null || rawDesc === undefined ? '' : rawDesc).trim();
    
    if (!rawCodeStr) return;
    
    // Apply normalization
    let normCode = rawCodeStr.replace(/\s+/g, '');
    if (normCode.length % 2 !== 0 && normCode.length >= 5) {
        normCode = normCode.padStart(normCode.length + 1, '0');
    }
    
    if (CONFLICT_ROWS.has(excelRowNum)) {
        report.push({
            excelRow: excelRowNum,
            rawCellValue: rawCodeStr,
            rawCellType: typeof rawCode,
            rawNumericValue: rawCode,
            normalizedCode: normCode,
            description: rawDescStr,
            isConflictRow: true,
            firstSeenAt: normalized.has(normCode) ? normalized.get(normCode).excelRow : null,
            firstSeenDesc: normalized.has(normCode) ? normalized.get(normCode).description : null
        });
    }
    
    // Check if we'd conflict with existing
    if (normalized.has(normCode)) {
        const existing = normalized.get(normCode);
        if (!CONFLICT_ROWS.has(excelRowNum) && !CONFLICT_ROWS.has(existing.excelRow)) {
            // non-target conflict
        }
    } else {
        normalized.set(normCode, { excelRow: excelRowNum, description: rawDescStr, rawCode: rawCodeStr });
    }
});

// For each conflict row, also show the "winner" row
for (const conflictRow of report) {
    const winnerKey = conflictRow.normalizedCode;
    const winner = normalized.get(winnerKey);
    conflictRow.winnerExcelRow = winner ? winner.excelRow : 'NOT FOUND';
    conflictRow.winnerDescription = winner ? winner.description : 'NOT FOUND';
    conflictRow.winnerRawCode = winner ? winner.rawCode : 'NOT FOUND';
}

fs.writeFileSync('conflict_ledger.json', JSON.stringify(report, null, 2));
console.log('Conflict ledger written:');
console.log(JSON.stringify(report, null, 2));
