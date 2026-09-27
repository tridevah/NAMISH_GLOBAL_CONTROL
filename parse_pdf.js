const fs = require('fs');
const pdf = require('pdf-parse');

let dataBuffer = fs.readFileSync('hsn.pdf');

pdf(dataBuffer).then(function(data) {
    const lines = data.text.split('\n');
    lines.forEach((line, index) => {
        if (line.includes('5208') || line.includes('Lungi') || line.includes('Shirting')) {
            console.log(`Line ${index}: ${line}`);
        }
    });
});
