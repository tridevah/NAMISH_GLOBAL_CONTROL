const fs = require('fs');
const readline = require('readline');
const path = require('path');

const FILE_PATH = 'D:\\ANTIGRAVITY_WORKSPACE\\INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826\\PIN CODE.csv';
const RUNTIME_DIR = 'D:\\ANTIGRAVITY_WORKSPACE\\LGD_IMPORT_RUNTIME\\R4';

async function checkUniqueness() {
    const stream = fs.createReadStream(FILE_PATH);
    const rl = readline.createInterface({ input: stream, crlfDelay: Infinity });

    let headers = [];
    let seen = new Map();
    let collisions = [];
    let totalRows = 0;

    for await (const line of rl) {
        if (!line.trim()) continue;
        
        // rudimentary CSV split (ignores quoted commas, but PIN CODE.csv usually uses quotes for strings with commas? 
        // Let's use a slightly better split or just regex since the sample showed:
        // "Telangana Circle","Hyderabad Region","Adilabad Division","Kothimir B.O",504273,BO,Delivery,"KUMURAM BHEEM ASIFABAD",TELANGANA,19.3638689,79.5376658
        const cols = line.match(/(".*?"|[^",\s]+)(?=\s*,|\s*$)/g) || [];
        const cleanCols = cols.map(c => c.replace(/^"|"$/g, '').trim());

        if (headers.length === 0) {
            headers = cleanCols.map(h => h.toLowerCase());
            continue;
        }

        totalRows++;
        let rowObj = {};
        headers.forEach((h, i) => { rowObj[h] = cleanCols[i]; });

        const pincode = String(rowObj['pincode']).trim();
        const officename = String(rowObj['officename']).trim().toLowerCase();
        
        const key = pincode + '|' + officename;

        if (seen.has(key)) {
            // Collision detected!
            collisions.push({
                PIN: pincode,
                Office_Name: rowObj['officename'],
                Office_Type: rowObj['officetype'],
                Delivery_Status: rowObj['delivery'],
                Division: rowObj['divisionname'],
                Region: rowObj['regionname'],
                State_District: rowObj['statename'] + ' / ' + rowObj['district']
            });
            // We can also push the previously seen one if we want full evidence, but this is enough evidence
        } else {
            seen.set(key, true);
        }
    }

    if (collisions.length > 0) {
        console.log(JSON.stringify({ status: 'COLLISIONS_FOUND', totalRows, distinctRows: seen.size, collisionCount: collisions.length, sample: collisions.slice(0, 50) }, null, 2));
        fs.writeFileSync(path.join(RUNTIME_DIR, 'STOP_REQUESTED'), '');
    } else {
        console.log(JSON.stringify({ status: 'VALIDATED', totalRows, distinctRows: seen.size }));
    }
}

checkUniqueness().catch(console.error);
