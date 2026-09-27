const fs = require('fs');

const f1 = fs.readFileSync('normalized_sac_source.json', 'utf8').split('\n');

const sacMapOld = new Map();
// Re-parse the old way
const xlsx = require('xlsx');
const wb = xlsx.readFile('HSN_Directory.xlsx');
const sacSheet = wb.Sheets['SAC_MSTR'];
const sacRawRows = xlsx.utils.sheet_to_json(sacSheet, { header: 1, defval: '', raw: true });

sacRawRows.slice(1).forEach(row => {
    let code = String(row[0]).trim().replace(/\s+/g, '');
    if (!code) return;
    if (!['2','4','6'].includes(String(code.length))) return; 
    if (code === '999692' || code === '999694') return;
    if (!sacMapOld.has(code)) {
        let desc = String(row[1]).trim().replace(/\r\n|\r|\n/g, ' ').replace(/\s+/g, ' ');
        let classification_level = null;
        if (code.length === 2) { classification_level = 'CHAPTER'; }
        else if (code.length === 4) { classification_level = 'HEADING'; }
        else if (code.length === 6) { classification_level = 'SERVICE_CODE'; }
        sacMapOld.set(code, { code_type: 'SAC', code, description: desc, parent_code: null, classification_level });
    }
});
for (const [code, val] of sacMapOld.entries()) {
    let parent_code = null;
    let len = code.length;
    while (len > 2) {
        len -= 2;
        let cand = code.substring(0, len);
        if (sacMapOld.has(cand)) { parent_code = cand; break; }
    }
    val.parent_code = parent_code;
}

const arrOld = Array.from(sacMapOld.values());
arrOld.sort((a, b) => {
    if (a.code_type < b.code_type) return -1;
    if (a.code_type > b.code_type) return 1;
    if (a.code < b.code) return -1;
    if (a.code > b.code) return 1;
    return 0;
});

const linesOld = arrOld.map(r => {
    return JSON.stringify({
        code_type: r.code_type,
        code: r.code,
        description: r.description ? String(r.description).normalize('NFC') : null,
        parent_code: r.parent_code || null,
        classification_level: r.classification_level || null
    });
});

let diffStr = '';
for(let i=0; i < Math.min(f1.length, linesOld.length); i++) {
    if (f1[i] !== linesOld[i]) {
        diffStr += `Line ${i+1}:\nOLD: ${linesOld[i]}\nNEW: ${f1[i]}\n`;
    }
}
console.log(diffStr || "No differences found.");
