const fs = require('fs');

const buf = fs.readFileSync('hsn.pdf');
let offset = 0;
let count = 0;

while (true) {
    const start = buf.indexOf(Buffer.from([0xFF, 0xD8, 0xFF]), offset);
    if (start === -1) break;
    const end = buf.indexOf(Buffer.from([0xFF, 0xD9]), start);
    if (end === -1) break;
    
    count++;
    const jpegBuf = buf.slice(start, end + 2);
    // Let's assume page ~ index + offset
    fs.writeFileSync(`page_${count}.jpg`, jpegBuf);
    offset = end + 2;
}
console.log(`Total images found: ${count}`);
