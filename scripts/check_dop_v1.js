const fs = require('fs');
const readline = require('readline');
const FILE_PATH = 'D:\\ANTIGRAVITY_WORKSPACE\\INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826\\PIN CODE.csv';
async function run() {
    const stream = fs.createReadStream(FILE_PATH);
    const rl = readline.createInterface({ input: stream, crlfDelay: Infinity });
    let headers = [];
    let map = new Map();
    let collisions = new Map();
    let total = 0;
    
    for await (const line of rl) {
        if (!line.trim()) continue;
        const cols = line.match(/(".*?"|[^",\s]+)(?=\s*,|\s*$)/g) || [];
        const cleanCols = cols.map(c => c.replace(/^"|"$/g, '').trim());
        if (headers.length === 0) {
            headers = cleanCols.map(h => h.toLowerCase());
            continue;
        }
        total++;
        let r = {}; headers.forEach((h, i) => r[h] = cleanCols[i]);
        
        // DOP_PIN_CSV_V1
        const country = 'IND';
        const pincode = String(r.pincode).trim();
        const officeName = String(r.officename).trim().toLowerCase().replace(/\s+/g, ' ');
        const officeType = String(r.officetype).trim().toUpperCase();
        const state = String(r.statename).trim().toLowerCase().replace(/\s+/g, ' ');
        const district = String(r.district).trim().toLowerCase().replace(/\s+/g, ' ');
        const division = String(r.divisionname).trim().toLowerCase().replace(/\s+/g, ' ');
        
        // Also let's just make it a clean concatenated string
        const key = [country, pincode, officeName, officeType, state, district, division].join('|');
        
        if (map.has(key)) {
            // Need to check if it's an EXACT duplicate row (allowed as observation) or conflict
            // The prompt says "Exact duplicate row -> one office, multiple source observations"
            // Let's check if the raw row strings are identical (excluding lat/long or whatever?)
            // Wait, the CSV might have duplicate rows entirely.
            // Let's just count unique keys vs total, and see if there are DIFFERENT rows sharing the key
            const existing = map.get(key);
            const isExactMatch = 
                existing.regionname === r.regionname &&
                existing.circlename === r.circlename &&
                existing.delivery === r.delivery; // Check other important fields
            
            if (!isExactMatch) {
                if (!collisions.has(key)) collisions.set(key, [existing]);
                collisions.get(key).push(r);
            }
        } else {
            map.set(key, r);
        }
    }
    
    console.log(JSON.stringify({ 
        total, 
        distinctKeys: map.size, 
        collisions: collisions.size,
        sample: Array.from(collisions.entries()).slice(0, 3) 
    }));
}
run();
