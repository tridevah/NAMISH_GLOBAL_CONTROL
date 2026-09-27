const fs = require('fs');
const crypto = require('crypto');
const readline = require('readline');

const FILE = 'D:\\ANTIGRAVITY_WORKSPACE\\INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826\\PIN CODE.csv';
const norm = s => String(s||'').normalize('NFKC').toLowerCase().replace(/\s+/g,' ').trim();

// Verify that the original 25 name+pin collisions are separated by DOP_PIN_CSV_V1
const KNOWN_COLLISIONS = [
    ['203001','Dariyapur BO'],
    ['503003','MAMIDIPALLI B.O'],
    ['509320','Madharam B.O'],
    ['423101','Talwade B.O'],
    ['226010','Gomti Nagar Extension SO Lucknow'],
    ['673579','Pakkom BO'],
];

async function run() {
    const rl = readline.createInterface({ input: fs.createReadStream(FILE), crlfDelay: Infinity });
    let headers = [];
    const caseMap = new Map();  // (pin|name) -> [{hash, basis}]

    for await (const line of rl) {
        if (!line.trim()) continue;
        const cols = line.match(/(".*?"|[^",\r\n]+)/g) || [];
        const c = cols.map(x => x.replace(/^"|"$/g,'').trim());
        if (!headers.length) { headers = c.map(h => h.toLowerCase()); continue; }
        const r = {}; headers.forEach((h,i) => r[h] = c[i]||'');
        
        const basis = {
            country:'IND', pincode:String(r.pincode).trim(),
            office: norm(r.officename), type: norm(r.officetype),
            state: norm(r.statename), district: norm(r.district), division: norm(r.divisionname)
        };
        const hash = crypto.createHash('sha256').update(Object.values(basis).join('\x1f'),'utf8').digest('hex');
        const simpleKey = basis.pincode + '|' + basis.office;

        if (!caseMap.has(simpleKey)) caseMap.set(simpleKey, []);
        caseMap.get(simpleKey).push({ hash, basis });
    }

    for (const [pin, name] of KNOWN_COLLISIONS) {
        const key = pin + '|' + norm(name);
        const entries = caseMap.get(key) || [];
        const uniqueHashes = new Set(entries.map(e => e.hash));
        console.log([
            'PIN=' + pin,
            'NAME=' + name,
            'RAW_ROWS=' + entries.length,
            'UNIQUE_DOP_HASHES=' + uniqueHashes.size,
            uniqueHashes.size === entries.length ? 'RESOLVED' : 'STILL_COLLIDING'
        ].join(' | '));
    }
}
run().catch(console.error);
