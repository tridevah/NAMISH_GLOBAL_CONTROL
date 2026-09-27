const fs = require('fs');
const readline = require('readline');
const FILE_PATH = 'D:\\ANTIGRAVITY_WORKSPACE\\INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826\\PIN CODE.csv';
async function run() {
    const stream = fs.createReadStream(FILE_PATH);
    const rl = readline.createInterface({ input: stream, crlfDelay: Infinity });
    let headers = [];
    let map = new Map();
    let collisions = new Map();
    
    for await (const line of rl) {
        if (!line.trim()) continue;
        const cols = line.match(/(".*?"|[^",\s]+)(?=\s*,|\s*$)/g) || [];
        const cleanCols = cols.map(c => c.replace(/^"|"$/g, '').trim());
        if (headers.length === 0) {
            headers = cleanCols.map(h => h.toLowerCase());
            continue;
        }
        let r = {}; headers.forEach((h, i) => r[h] = cleanCols[i]);
        const key = String(r.pincode).trim() + '|' + String(r.officename).trim().toLowerCase();
        
        const summary = {
            PIN: r.pincode, OfficeName: r.officename, Type: r.officetype, Delivery: r.delivery,
            Division: r.divisionname, Region: r.regionname, StateDist: r.statename + ' / ' + r.district
        };
        
        if (map.has(key)) {
            if (!collisions.has(key)) collisions.set(key, [map.get(key)]);
            collisions.get(key).push(summary);
        } else {
            map.set(key, summary);
        }
    }
    
    for (const [k, arr] of Array.from(collisions.entries()).slice(0, 3)) {
        console.log(\\n=== COLLISION DETECTED: \ ===\);
        console.table(arr);
    }
}
run();
