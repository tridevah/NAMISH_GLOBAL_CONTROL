const fs = require('fs');
const raw = fs.readFileSync('D:\\ANTIGRAVITY_WORKSPACE\\INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826\\PIN CODE.csv', 'utf8');
const lines = raw.split('\n').map(l => l.trim()).filter(l => l);

const identities = new Map();
const rawSet = new Set();
let exactPayloadExcess = 0;

for(let i=1; i<lines.length; i++) {
    const lineStr = lines[i];
    if (rawSet.has(lineStr)) exactPayloadExcess++; else rawSet.add(lineStr);

    const r = []; let col='', inQ=false;
    for (const ch of lineStr) { if(ch==='"') inQ=!inQ; else if(ch===','&&!inQ) { r.push(col.trim()); col=''; } else col+=ch; }
    r.push(col.trim());
    
    const basis = {
        office_name: r[3].toUpperCase().replace(/[\\s\\.]+/g, ' ').trim(),
        pincode: r[4],
        state_name: r[8],
        district_name: r[7]
    };
    const key = JSON.stringify(basis);
    if (!identities.has(key)) identities.set(key, []);
    identities.get(key).push({row: i, r: r, basis: basis});
}

const groups = [];
for (const [key, group] of identities.entries()) {
    if (group.length > 1) {
        // filter out exact payload matches that are just 100% identical lines?
        // the prompt wants "For every normalization-equivalent group, return: physical row numbers..."
        let isAmbiguous = false;
        const first = group[0].r;
        for(let j=1; j<group.length; j++) {
            const row = group[j].r;
            if (row[4] !== first[4] || row[5] !== first[5] || row[8] !== first[8] || row[7] !== first[7] || row[2] !== first[2]) {
                isAmbiguous = true;
            }
        }
        groups.push({
            reason: isAmbiguous ? 'REVIEW_REQUIRED_DIVISION_MISMATCH' : 'MERGE_LAT_LONG_OR_PUNCTUATION',
            rows: group.map(g => ({
                row: g.row,
                PIN: g.r[4],
                original_office: g.r[3],
                normalized_office: g.basis.office_name,
                type: g.r[5],
                state: g.r[8],
                district: g.r[7],
                division: g.r[2],
                coordinates: g.r[9] + ', ' + g.r[10]
            }))
        });
    }
}
console.log(JSON.stringify(groups, null, 2));
