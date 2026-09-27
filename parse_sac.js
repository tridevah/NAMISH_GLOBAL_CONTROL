const fs = require('fs');
const pdf = require('pdf-parse');

let dataBuffer = fs.readFileSync('sac.pdf');

pdf(dataBuffer).then(function(data) {
    const lines = data.text.split('\n');
    let found = [];
    for(let i=0; i<lines.length; i++) {
        if(lines[i].trim() === '696' || lines[i].includes('696') || lines[i].trim() === '698' || lines[i].includes('698')) {
            found.push(lines.slice(Math.max(0, i-2), i+3).join('\n'));
            found.push('---');
        }
    }
    console.log(found.join('\n'));
}).catch(e => console.error(e));
