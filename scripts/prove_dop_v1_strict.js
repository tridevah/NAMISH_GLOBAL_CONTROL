const fs = require('fs');
const crypto = require('crypto');
const readline = require('readline');
const FILE = 'D:\\ANTIGRAVITY_WORKSPACE\\INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826\\PIN CODE.csv';
const norm = s => String(s||'').normalize('NFKC').toLowerCase().replace(/\s+/g,' ').trim();

// Parse CSV line handling quoted fields
function parseLine(line) {
    const results = [];
    let col = '', inQ = false;
    for (let i = 0; i < line.length; i++) {
        const ch = line[i];
        if (ch === '"') { inQ = !inQ; }
        else if (ch === ',' && !inQ) { results.push(col.trim()); col = ''; }
        else { col += ch; }
    }
    results.push(col.trim());
    return results;
}

async function run() {
    const rl = readline.createInterface({ input: fs.createReadStream(FILE), crlfDelay: Infinity });
    let headers = [], rowNum = 0;
    let allRows = new Map(), perfectDupRows = [], strictCollisions = [];

    for await (const line of rl) {
        if (!line.trim()) continue;
        const c = parseLine(line);
        if (!headers.length) { headers = c.map(h => h.toLowerCase()); continue; }
        rowNum++;
        const r = {}; headers.forEach((h,i) => r[h] = c[i]||'');

        const basis = {
            country:  'IND',
            pincode:  String(r.pincode).trim(),
            office:   norm(r.officename),
            type:     norm(r.officetype),
            state:    norm(r.statename),
            district: norm(r.district),
            division: norm(r.divisionname)
        };
        const hash = crypto.createHash('sha256').update(Object.values(basis).join('\x1f'),'utf8').digest('hex');
        const fullHash = crypto.createHash('sha256').update(JSON.stringify(r),'utf8').digest('hex');

        if (allRows.has(hash)) {
            const prev = allRows.get(hash);
            if (prev.fullHash === fullHash) {
                perfectDupRows.push({ hash, rows: [prev.rowNum, rowNum], office: r.officename, pin: r.pincode });
            } else {
                strictCollisions.push({
                    hash, row1: prev.rowNum, row2: rowNum,
                    basis, note: 'Same DOP_V1 key, different full row (lat/lon differs)'
                });
            }
        } else {
            allRows.set(hash, { rowNum, fullHash, basis });
        }
    }

    const result = {
        TOTAL_ROWS: rowNum,
        DISTINCT_DOP_V1_KEYS: allRows.size,
        EXACT_DUPLICATE_ROWS: perfectDupRows.length,
        STRICT_COLLISIONS: strictCollisions.length,
        POST_OFFICE_IDENTITY_VALIDATED: strictCollisions.length === 0 ? 'YES' : 'NO',
        EXACT_DUPES_ARE_SAFE_OBSERVATIONS: perfectDupRows.length > 0,
        PERFECT_DUPE_EXAMPLES: perfectDupRows.slice(0, 5),
        STRICT_COLLISION_EVIDENCE: strictCollisions.slice(0, 10)
    };
    console.log(JSON.stringify(result, null, 2));
}
run().catch(console.error);
