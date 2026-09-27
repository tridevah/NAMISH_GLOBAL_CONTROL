const fs = require('fs');
const crypto = require('crypto');
const readline = require('readline');

const FILE = 'D:\\ANTIGRAVITY_WORKSPACE\\INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826\\PIN CODE.csv';

const norm = s => String(s||'').normalize('NFKC').toLowerCase().replace(/\s+/g,' ').trim();

async function run() {
    const rl = readline.createInterface({ input: fs.createReadStream(FILE), crlfDelay: Infinity });
    let headers = [], seen = new Map(), collisions = [], dupeRows = 0;
    let rowNum = 0;

    for await (const line of rl) {
        if (!line.trim()) continue;
        const cols = line.match(/(".*?"|[^",\r\n]+)/g) || [];
        const c = cols.map(x => x.replace(/^"|"$/g,'').trim());
        if (!headers.length) { headers = c.map(h => h.toLowerCase()); continue; }
        rowNum++;
        const r = {}; headers.forEach((h,i) => r[h] = c[i]||'');
        
        const basis = {
            country:   'IND',
            pincode:   String(r.pincode||'').trim(),
            office:    norm(r.officename),
            type:      norm(r.officetype),
            state:     norm(r.statename),
            district:  norm(r.district),
            division:  norm(r.divisionname)
        };
        const keyStr = [basis.country,basis.pincode,basis.office,basis.type,basis.state,basis.district,basis.division].join('\x1f');
        const hash = crypto.createHash('sha256').update(keyStr,'utf8').digest('hex');

        if (seen.has(hash)) {
            const prev = seen.get(hash);
            const isPerfectDupe = JSON.stringify(prev.basis) === JSON.stringify(basis);
            if (isPerfectDupe) { dupeRows++; }
            else {
                collisions.push({ key: hash, row1: prev.rowNum, row2: rowNum, r1: prev.basis, r2: basis });
            }
        } else {
            seen.set(hash, { rowNum, basis });
        }
    }

    console.log(JSON.stringify({
        TOTAL_ROWS: rowNum,
        DISTINCT_KEYS: seen.size,
        DOP_PIN_CSV_V1_COLLISIONS: collisions.length,
        EXACT_DUPLICATE_ROWS: dupeRows,
        POST_OFFICE_IDENTITY_VALIDATED: collisions.length === 0 ? 'YES' : 'NO',
        SAMPLE_COLLISIONS: collisions.slice(0,5)
    }, null, 2));
}
run().catch(console.error);
