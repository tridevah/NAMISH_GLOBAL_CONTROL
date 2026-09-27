const fs = require('fs');
const readline = require('readline');
const rl = readline.createInterface({
    input: fs.createReadStream('D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826/PIN CODE.csv')
});

let pins = new Set();
let isFirst = true;
rl.on('line', line => {
    if (isFirst) { isFirst = false; return; }
    // handles quotes if any but basic split is fine for PIN
    const match = line.match(/(?:^|,)(?:"([^"]*)"|([^,]*))/g);
    if (!match) return;
    const parts = match.map(m => m.replace(/^,/, '').replace(/^"|"$/g, '').trim());
    if (parts.length > 4) {
        pins.add(parts[4]);
    }
});
rl.on('close', () => {
    console.log('Distinct PINs:', pins.size);
});
