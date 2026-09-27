const fs = require('fs');
const pdfjsLib = require('pdfjs-dist/legacy/build/pdf.js');
const { createCanvas } = require('canvas');

const pdfPath = 'hsn.pdf';

async function renderPages() {
    const data = new Uint8Array(fs.readFileSync(pdfPath));
    const loadingTask = pdfjsLib.getDocument({ data });
    const pdfDocument = await loadingTask.promise;
    console.log(`Total Pages: ${pdfDocument.numPages}`);
    
    for (let i = 477; i <= Math.min(479, pdfDocument.numPages); i++) {
        const page = await pdfDocument.getPage(i);
        const viewport = page.getViewport({ scale: 2.0 });
        const canvas = createCanvas(viewport.width, viewport.height);
        const ctx = canvas.getContext('2d');
        
        const renderContext = {
            canvasContext: ctx,
            viewport: viewport
        };
        await page.render(renderContext).promise;
        
        const buffer = canvas.toBuffer('image/png');
        fs.writeFileSync(`page_${i}.png`, buffer);
        console.log(`Rendered page_${i}.png`);
    }
}

renderPages().catch(console.error);
