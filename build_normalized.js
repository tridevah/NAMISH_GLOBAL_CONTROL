const fs = require('fs');
const xlsx = require('xlsx');
const crypto = require('crypto');

function writeNormalized(filename, data) {
    // UTF-8, Unicode NFC, LF newlines, fixed field order, sorted by code_type, code
    data.sort((a, b) => {
        if (a.code_type < b.code_type) return -1;
        if (a.code_type > b.code_type) return 1;
        if (a.code < b.code) return -1;
        if (a.code > b.code) return 1;
        return 0;
    });

    const lines = data.map(row => {
        const obj = {
            code_type: row.code_type,
            code: row.code,
            description: row.description ? String(row.description).normalize('NFC') : null,
            parent_code: row.parent_code || null,
            classification_level: row.classification_level || null
        };
        return JSON.stringify(obj);
    });

    fs.writeFileSync(filename, lines.join('\n') + '\n', { encoding: 'utf8' });
}

const wb = xlsx.readFile('HSN_Directory.xlsx');

// HSN
const hsnSheet = wb.Sheets['HSN_MSTR'];
const hsnRawRows = xlsx.utils.sheet_to_json(hsnSheet, { header: 1, defval: '', raw: true });
const hsnMap = new Map();

// 7 exact conflict resolutions
const hsnResolutions = {
    '230700': 'Wine lees; argol',
    '251400': 'Slate, whether or not roughly trimmed or merely cut, by sawing or otherwise, into blocks or slabs of a rectangular (including square) shape',
    '030559': 'Other :',
    '03074330': 'Squid tubes',
    '040210': 'In powder, granules or other solid forms, of a fat content, by weight not exceeding 1.5% :',
    '05119110': 'Fish nails',
    '090121': 'Not decaffeinated :'
};

// Merge extracted legal source artifacts
const extractedChapter52 = JSON.parse(fs.readFileSync('extracted_chapter52.json', 'utf8'));
Object.assign(hsnResolutions, extractedChapter52.extracted);

hsnRawRows.slice(1).forEach(row => {
    let code = String(row[0]).trim().replace(/\s+/g, '');
    if (!code) return;
    if (code.length % 2 !== 0 && code.length >= 5) code = code.padStart(code.length + 1, '0');
    if (!['2','4','6','8'].includes(String(code.length))) return; 

    if (!hsnMap.has(code)) {
        let desc = String(row[1]).trim().replace(/\r\n|\r|\n/g, ' ');
        if (hsnResolutions[code]) desc = hsnResolutions[code];

        let classification_level = null;
        if (code.length === 2) { classification_level = 'CHAPTER'; }
        else if (code.length === 4) { classification_level = 'HEADING'; }
        else if (code.length === 6) { classification_level = 'SUBHEADING'; }
        else if (code.length === 8) { classification_level = 'ITEM'; }

        hsnMap.set(code, {
            code_type: 'HSN',
            code,
            description: desc,
            parent_code: null, // to be populated
            classification_level
        });
    }
});

// Second pass for parents
for (const [code, val] of hsnMap.entries()) {
    let parent_code = null;
    let len = code.length;
    while (len > 2) {
        len -= 2;
        let cand = code.substring(0, len);
        if (hsnMap.has(cand)) {
            parent_code = cand;
            break;
        }
    }
    val.parent_code = parent_code;
}

writeNormalized('normalized_hsn_source.json', Array.from(hsnMap.values()));

// SAC
const sacSheet = wb.Sheets['SAC_MSTR'];
const sacRawRows = xlsx.utils.sheet_to_json(sacSheet, { header: 1, defval: '', raw: true });
const sacMap = new Map();

sacRawRows.slice(1).forEach(row => {
    let code = String(row[0]).trim().replace(/\s+/g, '');
    if (!code) return;
    if (!['2','4','6'].includes(String(code.length))) return; 
    
    // 12/2023 amendment exclusions
    if (code === '999692' || code === '999694') return;

    if (!sacMap.has(code)) {
        let desc = String(row[1]).trim().replace(/\r\n|\r|\n/g, ' ');

        let classification_level = null;
        if (code.length === 2) { classification_level = 'CHAPTER'; }
        else if (code.length === 4) { classification_level = 'HEADING'; }
        else if (code.length === 6) { classification_level = 'SERVICE_CODE'; }

        sacMap.set(code, {
            code_type: 'SAC',
            code,
            description: desc,
            parent_code: null, // to be populated
            classification_level
        });
    }
});

// Second pass for SAC parents
for (const [code, val] of sacMap.entries()) {
    let parent_code = null;
    let len = code.length;
    while (len > 2) {
        len -= 2;
        let cand = code.substring(0, len);
        if (sacMap.has(cand)) {
            parent_code = cand;
            break;
        }
    }
    val.parent_code = parent_code;
}

writeNormalized('normalized_sac_source.json', Array.from(sacMap.values()));
console.log('Normalized source files generated.');
