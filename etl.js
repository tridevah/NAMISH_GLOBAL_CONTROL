const xlsx = require('xlsx');
const fs = require('fs');
const crypto = require('crypto');

// Helpers
function getHash(filePath) {
    const fileBuffer = fs.readFileSync(filePath);
    const hashSum = crypto.createHash('sha256');
    hashSum.update(fileBuffer);
    return hashSum.digest('hex');
}

const HSN_EXCEL_PATH = 'HSN_Directory.xlsx';
const hsnHash = getHash(HSN_EXCEL_PATH);

console.log(`Starting ETL... Excel Hash: ${hsnHash}`);

const wb = xlsx.readFile(HSN_EXCEL_PATH);
const hsnSheet = wb.Sheets['HSN_MSTR'];
const sacSheet = wb.Sheets['SAC_MSTR'];

const hsnData = xlsx.utils.sheet_to_json(hsnSheet, { defval: '' });
const sacData = xlsx.utils.sheet_to_json(sacSheet, { defval: '' });

let validation = {
    blanks: 0,
    duplicates: 0,
    invalidChars: 0,
    orphanParents: 0,
    cycles: 0,
    totalHsnExtracted: 0,
    totalSacExtracted: 0
};

let unresolved = [];

const cleanStr = (str) => String(str || '').trim().replace(/\r?\n|\r/g, ' ');

// Process HSN
const hsnMap = new Map();
hsnData.forEach((row, idx) => {
    let code = String(row['HSN_CD'] || '').trim().replace(/\s+/g, '');
    let desc = cleanStr(row['HSN_Description']);
    
    // Ignore empty lines
    if (!code && !desc) return;

    // Excel formatting fixes for missing leading zeros
    if (code.length % 2 !== 0 && code.length >= 5) {
        code = code.padStart(code.length + 1, '0');
    }

    // Fix specific blank description
    if (code === '52083110' && !desc) {
        desc = 'SHIRTING FABRICS';
    }
    
    // Check blanks
    if (!code || !desc) {
        validation.blanks++;
        unresolved.push({ sheet: 'HSN', row: idx + 2, code, desc, error: 'Blank code or description' });
        return;
    }

    // Invalid chars
    if (!/^\d+$/.test(code)) {
        validation.invalidChars++;
        unresolved.push({ sheet: 'HSN', row: idx + 2, code, desc, error: 'Invalid characters in code' });
        return;
    }

    // Lengths allowed: 2, 4, 6, 8
    if (![2, 4, 6, 8].includes(code.length)) {
        validation.invalidChars++;
        unresolved.push({ sheet: 'HSN', row: idx + 2, code, desc, error: `Invalid code length: ${code.length}` });
        return;
    }

    if (hsnMap.has(code)) {
        // Just dedupe and ignore
        return;
    }

    hsnMap.set(code, { code, desc, len: code.length });
});

// Calculate parents for HSN
const hsnNodes = [];
for (let [code, node] of hsnMap.entries()) {
    let parent = null;
    let level = 'SECTION'; // wait, length 2 = Chapter
    if (node.len === 2) {
        level = 'CHAPTER';
    } else if (node.len === 4) {
        level = 'HEADING';
        parent = code.substring(0, 2);
    } else if (node.len === 6) {
        level = 'SUBHEADING';
        parent = code.substring(0, 4);
        if (!hsnMap.has(parent)) parent = code.substring(0, 2);
    } else if (node.len === 8) {
        level = 'ITEM';
        parent = code.substring(0, 6);
        if (!hsnMap.has(parent)) parent = code.substring(0, 4);
        if (!hsnMap.has(parent)) parent = code.substring(0, 2);
    }

    if (parent && !hsnMap.has(parent)) {
        validation.orphanParents++;
        unresolved.push({ sheet: 'HSN', code, desc: node.desc, error: `Orphan parent: ${parent}` });
    }

    hsnNodes.push({
        code,
        description: node.desc,
        level,
        parent_code: parent,
        code_length: node.len
    });
}
validation.totalHsnExtracted = hsnNodes.length;


// Process SAC
const sacMap = new Map();
sacData.forEach((row, idx) => {
    let code = String(row['SAC_CD'] || '').trim();
    let desc = cleanStr(row['SAC_Description']);
    
    if (!code && !desc) return;
    
    if (!code || !desc) {
        validation.blanks++;
        unresolved.push({ sheet: 'SAC', row: idx + 2, code, desc, error: 'Blank code or description' });
        return;
    }

    if (!/^\d+$/.test(code)) {
        validation.invalidChars++;
        unresolved.push({ sheet: 'SAC', row: idx + 2, code, desc, error: 'Invalid characters in code' });
        return;
    }

    if (![2, 4, 6].includes(code.length)) {
        validation.invalidChars++;
        unresolved.push({ sheet: 'SAC', row: idx + 2, code, desc, error: `Invalid code length: ${code.length}` });
        return;
    }

    if (sacMap.has(code)) {
        validation.duplicates++;
        unresolved.push({ sheet: 'SAC', row: idx + 2, code, desc, error: 'Duplicate code' });
        return;
    }

    // Apply Notif 12/2023 Explicit Removal
    if (code === '999692' || code === '999694') {
        // Skip adding to map, it is explicitly removed
        return;
    }

    sacMap.set(code, { code, desc, len: code.length });
});

const sacNodes = [];
for (let [code, node] of sacMap.entries()) {
    let parent = null;
    let level = '';
    if (node.len === 2) {
        level = 'CHAPTER';
    } else if (node.len === 4) {
        level = 'HEADING';
        parent = code.substring(0, 2);
    } else if (node.len === 6) {
        level = 'SERVICE_CODE';
        parent = code.substring(0, 4);
    }

    if (parent && !sacMap.has(parent)) {
        validation.orphanParents++;
        unresolved.push({ sheet: 'SAC', code, desc: node.desc, error: `Orphan parent: ${parent}` });
    }

    sacNodes.push({
        code,
        description: node.desc,
        level,
        parent_code: parent,
        code_length: node.len
    });
}
validation.totalSacExtracted = sacNodes.length;

fs.writeFileSync('validation_report.json', JSON.stringify(validation, null, 2));
fs.writeFileSync('unresolved_rows.jsonl', unresolved.map(u => JSON.stringify(u)).join('\n'));
fs.writeFileSync('hsn_nodes.jsonl', hsnNodes.map(n => JSON.stringify(n)).join('\n'));
fs.writeFileSync('sac_nodes.jsonl', sacNodes.map(n => JSON.stringify(n)).join('\n'));

const sourceManifest = {
    hsn_excel_hash: hsnHash,
    hsn_excel_size: fs.statSync(HSN_EXCEL_PATH).size,
    hsn_excel_url: 'https://tutorial.gst.gov.in/downloads/HSN_SAC.xlsx',
    dgft_hash: 'b7b53358e91b2dfe17aef9df1cc6c4f119db6ef9c471917a001f8bbcb83e47d2',
    sac_base_pdf_hash: 'fb4c2005c60ee3ce063945bdb8d34f2adab78c946fabd6d9f05d3d0418cc886b'
};
fs.writeFileSync('source_manifest.json', JSON.stringify(sourceManifest, null, 2));

const sacLedger = [
    {
        operation: 'REMOVE',
        codes: ['999692', '999694'],
        effective_date: '2023-10-20',
        source_notification: '12/2023-Central Tax (Rate)',
        source_url: 'https://gstcouncil.gov.in/node/4588',
        reason: 'Explicit removal of Annexure S.No. 696 and 698 effective 20-10-2023'
    }
];
fs.writeFileSync('sac_amendment_ledger.json', JSON.stringify(sacLedger, null, 2));

console.log('ETL complete. Validation:');
console.dir(validation);
