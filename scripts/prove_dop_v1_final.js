const fs = require('fs');
const crypto = require('crypto');
const readline = require('readline');
const FILE = 'D:\\ANTIGRAVITY_WORKSPACE\\INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826\\PIN CODE.csv';
const norm = s => String(s||'').normalize('NFKC').toLowerCase().replace(/\s+/g,' ').trim();

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
    let identities = new Map();   // hash -> canonical office
    let observations = [];        // all source rows (including dupe/coord-only rows)
    let identityReviews = [];;    // ambiguous unresolvable records

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
        const rowHash = crypto.createHash('sha256').update(JSON.stringify(r),'utf8').digest('hex');

        if (identities.has(hash)) {
            const prev = identities.get(hash);
            // Check if the only difference is lat/lon or region/circle (source quality artefact)
            const isSameOffice = (
                basis.country === prev.basis.country &&
                basis.pincode === prev.basis.pincode &&
                basis.office  === prev.basis.office  &&
                basis.type    === prev.basis.type     &&
                basis.state   === prev.basis.state    &&
                basis.district=== prev.basis.district &&
                basis.division=== prev.basis.division
            );
            if (isSameOffice) {
                // Same canonical office — register as additional observation
                observations.push({ identity_hash: hash, rowNum, rowHash, raw: r, role: 'DUPLICATE_SOURCE_OBSERVATION' });
            } else {
                identityReviews.push({ hash, row1: prev.firstRowNum, row2: rowNum, basis, conflict: 'DOP_V1_KEY_COLLISION' });
            }
        } else {
            identities.set(hash, { basis, firstRowNum: rowNum, rowHash });
            observations.push({ identity_hash: hash, rowNum, rowHash, raw: r, role: 'PRIMARY_OBSERVATION' });
        }
    }

    const result = {
        TOTAL_SOURCE_ROWS: rowNum,
        CANONICAL_POST_OFFICES: identities.size,
        SOURCE_OBSERVATIONS: observations.length,
        DUPLICATE_SOURCE_ROWS: observations.filter(o => o.role === 'DUPLICATE_SOURCE_OBSERVATION').length,
        IDENTITY_REVIEWS_REQUIRED: identityReviews.length,
        POST_OFFICE_IDENTITY_VALIDATED: identityReviews.length === 0 ? 'YES' : 'NO',
        DUPLICATE_EXAMPLES: observations.filter(o => o.role === 'DUPLICATE_SOURCE_OBSERVATION')
            .slice(0,5).map(o => ({ pin: o.raw.pincode, office: o.raw.officename, rowNum: o.rowNum })),
        IDENTITY_REVIEWS: identityReviews
    };
    console.log(JSON.stringify(result, null, 2));
}
run().catch(console.error);
