const fs = require('fs');
const crypto = require('crypto');
const pdf = require('pdf-parse');
const path = require('path');

const filePath = path.join(__dirname, '../gst_sources/verified_v4_2/04-2017-CTR.pdf');
const buffer = fs.readFileSync(filePath);

const magic = buffer.slice(0, 5).toString('ascii');
const sha256 = crypto.createHash('sha256').update(buffer).digest('hex');

pdf(buffer).then(function(data) {
    const pageCount = data.numpages;
    const text = data.text;
    const hasText = text.includes('Notification No.4/2017-Central Tax (Rate)') || text.includes('Notification No. 4/2017') || text.includes('Notification No. 4 /2017');
    console.log(`First five bytes: ${magic}`);
    console.log(`Page count: ${pageCount}`);
    console.log(`Contains text "Notification No.4/2017-Central Tax (Rate)": ${hasText}`);
    console.log(`SHA256: ${sha256}`);
});
