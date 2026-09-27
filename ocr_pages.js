const Tesseract = require('tesseract.js');
const fs = require('fs');

async function ocrAll() {
    for (let i = 1; i <= 9; i++) {
        console.log(`Processing page_${i}.jpg...`);
        const result = await Tesseract.recognize(`page_${i}.jpg`, 'eng');
        const text = result.data.text;
        
        if (text.includes('5208') || text.toLowerCase().includes('lungi') || text.toLowerCase().includes('shirting')) {
            console.log(`\n\n--- MATCH FOUND ON PAGE ${i} ---`);
            console.log(text);
            fs.writeFileSync(`ocr_page_${i}.txt`, text);
            fs.writeFileSync(`ocr_page_${i}.tsv`, result.data.tsv);
        }
    }
    console.log("Done.");
}

ocrAll().catch(console.error);
