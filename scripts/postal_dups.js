const fs = require('fs');

const raw = fs.readFileSync('D:\\ANTIGRAVITY_WORKSPACE\\INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826\\PIN CODE.csv', 'utf8');
const lines = raw.split('\n').map(l => l.trim()).filter(l => l);

const identities = new Map();
const originalIdentities = new Map();

for(let i=1; i<lines.length; i++) {
    const r = []; let col='', inQ=false;
    for (const ch of lines[i]) { if(ch==='"') inQ=!inQ; else if(ch===','&&!inQ) { r.push(col.trim()); col=''; } else col+=ch; }
    r.push(col.trim());
    
    const rd = {
        officename: r[3], pincode: r[4], officetype: r[5], delivery: r[6],
        district: r[7], statename: r[8], lat: r[9], lon: r[10]
    };

    const basis = {
        office_name: rd.officename.toUpperCase().replace(/[\\s\\.]+/g, ' ').trim(),
        pincode: rd.pincode,
        state_name: rd.statename,
        district_name: rd.district
    };
    const key = JSON.stringify(basis);
    if(!identities.has(key)) identities.set(key, []);
    identities.get(key).push(rd);
}

for (const [key, group] of identities.entries()) {
    if (group.length > 1) {
        console.log(group);
    }
}
