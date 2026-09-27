import fs from 'fs';
import * as pdfjsLib from 'pdfjs-dist/legacy/build/pdf.mjs';

const pdfPath = 'ITC-HS_2022.pdf';

async function extractText() {
    const data = new Uint8Array(fs.readFileSync(pdfPath));
    const loadingTask = pdfjsLib.getDocument({ data });
    const pdfDocument = await loadingTask.promise;
    
    console.log(`Total Pages: ${pdfDocument.numPages}`);
    const targetPage = 364;
    
    const page = await pdfDocument.getPage(targetPage);
    const textContent = await page.getTextContent();
    const text = textContent.items.map(item => item.str).join(' ');
    
    // Simple regex or string matching to show it exists
    const lines = textContent.items.map(item => item.str);
    for (let i = 0; i < lines.length; i++) {
        if (lines[i].includes('5208') || lines[i].includes('Lungi') || lines[i].includes('Shirting')) {
            console.log(`[Extracted Line]: ${lines[i]}`);
        }
    }
}

extractText().catch(console.error);
