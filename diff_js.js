const fs = require('fs');

const f1 = fs.readFileSync('normalized_hsn_source.json', 'utf8').split('\n');
const f2 = fs.readFileSync('db_hsn_export.json', 'utf8').split('\n'); // Note: we renamed normalized_db_hsn.json to db_hsn_export.json earlier! So they SHOULD be identically formatted!

for(let i=0; i < Math.min(f1.length, f2.length); i++) {
    if (f1[i] !== f2[i]) {
        console.log(`Difference at line ${i+1}:`);
        console.log(`Source: ${f1[i]}`);
        console.log(`DB    : ${f2[i]}`);
        break;
    }
}
if(f1.length !== f2.length) console.log('Length mismatch:', f1.length, f2.length);
