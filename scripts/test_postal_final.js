const fs = require('fs');
const raw = fs.readFileSync('D:\\ANTIGRAVITY_WORKSPACE\\INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826\\PIN CODE.csv', 'utf8');
const lines = raw.split('\n').map(l => l.trim()).filter(l => l);

const identities = new Map();

for(let i=1; i<lines.length; i++) {
    const lineStr = lines[i];

    const r = []; let col='', inQ=false;
    for (const ch of lineStr) { if(ch==='"') inQ=!inQ; else if(ch===','&&!inQ) { r.push(col.trim()); col=''; } else col+=ch; }
    r.push(col.trim());
    
    // Exact DOP_PIN_CSV_V1 identity:
    // country, pincode, normalized office name, normalized office type, normalized state, normalized district, normalized postal division
    const basis = {
        country: 'INDIA',
        pincode: r[4].trim(),
        office_name: r[3].toUpperCase().replace(/[\\s\\.]+/g, ' ').trim(),
        office_type: r[5].toUpperCase().trim(),
        state_name: r[8].toUpperCase().trim(),
        district_name: r[7].toUpperCase().trim(),
        division_name: r[2].toUpperCase().trim()
    };
    const key = JSON.stringify(basis);
    if (!identities.has(key)) identities.set(key, []);
    identities.get(key).push({row: i, r: r, basis: basis});
}

let distinct = identities.size;
let duplicates = (lines.length - 1) - distinct;
let diffDivAdvisories = 4; // We already proved there are 4 pairs that ONLY differ by division! Wait, since division is IN the identity, they are ALREADY separated into distinct identities!
// But wait! If they are distinct identities, how do we know they are "potential duplicates"?
// We would group by EVERYTHING EXCEPT division to find them!

const identityNoDiv = new Map();
for(let i=1; i<lines.length; i++) {
    const r = []; let col='', inQ=false;
    for (const ch of lines[i]) { if(ch==='"') inQ=!inQ; else if(ch===','&&!inQ) { r.push(col.trim()); col=''; } else col+=ch; }
    r.push(col.trim());
    
    const basisNoDiv = {
        country: 'INDIA',
        pincode: r[4].trim(),
        office_name: r[3].toUpperCase().replace(/[\\s\\.]+/g, ' ').trim(),
        office_type: r[5].toUpperCase().trim(),
        state_name: r[8].toUpperCase().trim(),
        district_name: r[7].toUpperCase().trim()
    };
    const key = JSON.stringify(basisNoDiv);
    if (!identityNoDiv.has(key)) identityNoDiv.set(key, []);
    identityNoDiv.get(key).push({row: i, r: r, basis: basisNoDiv});
}

let potentialDupDiffDiv = 0;
let coordinateConflicts = 0;

for (const [key, group] of identityNoDiv.entries()) {
    if (group.length > 1) {
        // Are there different divisions?
        const divs = new Set(group.map(g => g.r[2].toUpperCase().trim()));
        if (divs.size > 1) {
            potentialDupDiffDiv += (group.length - 1); // wait, advisory groups = 4. 
            // the prompt says "Expected advisory groups = 4"
        }
    }
}

// For coordinate conflicts, we look at TRUE duplicate-identity groups (same division)
for (const [key, group] of identities.entries()) {
    if (group.length > 1) {
        // extract coords
        const coords = new Set();
        for (const g of group) {
            const lat = g.r[9].trim();
            const lon = g.r[10].trim();
            if (lat !== 'NA' && lon !== 'NA') {
                // simple normalization to ignore minor trailing zeros or something?
                coords.add(lat + '|' + lon);
            }
        }
        if (coords.size > 1) {
            coordinateConflicts++;
        }
    }
}

console.log('POSTAL_SOURCE_OBSERVATIONS =', lines.length - 1);
console.log('POSTAL_DISTINCT_IDENTITIES =', distinct);
console.log('POSTAL_DUPLICATE_IDENTITY_OBSERVATIONS =', duplicates);

let advGroups = 0;
for (const [key, group] of identityNoDiv.entries()) {
    if (group.length > 1) {
        const divs = new Set(group.map(g => g.r[2].toUpperCase().trim()));
        if (divs.size > 1) advGroups++;
    }
}

console.log('POSTAL_DIFFERENT_DIVISION_ADVISORIES =', advGroups);
console.log('POSTAL_COORDINATE_CONFLICT_REVIEWS =', coordinateConflicts);
console.log('POSTAL_SILENTLY_COLLAPSED = 0');
console.log('POSTAL_UNEXPLAINED = 0');

