import fs from 'fs';
import * as pdfjsLib from 'pdfjs-dist/legacy/build/pdf.mjs';

const pdfPath = 'ITC-HS_2022.pdf';

async function dumpPage364() {
    const data = new Uint8Array(fs.readFileSync(pdfPath));
    const pdfDocument = await pdfjsLib.getDocument({ data }).promise;
    
    const page = await pdfDocument.getPage(364);
    const textContent = await page.getTextContent();
    const items = textContent.items;
    
    console.log(`=== Page 364: ${items.length} text items ===\n`);
    items.forEach((item, i) => {
        if (item.str.trim()) {
            console.log(`[${i}] "${item.str}"`);
        }
    });
}

dumpPage364().catch(console.error);
