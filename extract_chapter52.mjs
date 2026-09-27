import fs from 'fs';
import crypto from 'crypto';
import * as pdfjsLib from 'pdfjs-dist/legacy/build/pdf.mjs';

const pdfPath = 'ITC-HS_2022.pdf';
const OUTPUT = 'extracted_chapter52.json';

async function extractPage364() {
    const data = new Uint8Array(fs.readFileSync(pdfPath));
    const pdfDocument = await pdfjsLib.getDocument({ data }).promise;

    const totalPages = pdfDocument.numPages; // must be 739
    const page = await pdfDocument.getPage(364);
    const textContent = await page.getTextContent();
    const items = textContent.items.map(i => i.str);

    // Walk token stream: when we find a subheading code, the description
    // is the next non-empty token that is not a dash sequence or unit.
    const unitPat = /^(m|m2|sq\.m|kg|u|-)$/i;
    const dashPat = /^-+$/;

    function descAfter(startIdx) {
        for (let j = startIdx + 1; j < Math.min(startIdx + 15, items.length); j++) {
            const t = items[j].trim();
            if (t.length === 0 || dashPat.test(t) || unitPat.test(t)) continue;
            if (/^\d/.test(t)) break; // next tariff code – no desc found before it
            return t;
        }
        return null;
    }

    const extracted = {};
    for (let i = 0; i < items.length; i++) {
        const tok = items[i].replace(/\s+/g, '');
        if (tok === '520831 10' || tok === '52083110') {
            extracted['52083110'] = descAfter(i);
        }
        if (tok === '520831 30' || tok === '52083130') {
            extracted['52083130'] = descAfter(i);
        }
    }

    // Second pass: match with spaces as pdfjs may emit "5208 31 10"
    for (let i = 0; i < items.length; i++) {
        const tok = items[i].replace(/\s+/g, '');
        if (tok === '52083110' && !extracted['52083110']) {
            extracted['52083110'] = descAfter(i);
        }
        if (tok === '52083130' && !extracted['52083130']) {
            extracted['52083130'] = descAfter(i);
        }
    }

    const result = {
        source_pdf: pdfPath,
        source_pdf_sha256: crypto.createHash('sha256').update(fs.readFileSync(pdfPath)).digest('hex').toUpperCase(),
        total_pages: totalPages,
        physical_page: 364,
        printed_page: 363,
        section: 'SECTION-XI/CHAPTER-52/5208/520831',
        extracted: extracted,
        extracted_at: new Date().toISOString()
    };

    fs.writeFileSync(OUTPUT, JSON.stringify(result, null, 2));
    console.log('Written:', OUTPUT);
    console.log('Extracted:', JSON.stringify(extracted, null, 2));
    console.log('Total pages:', totalPages);
    console.log('PDF SHA256:', result.source_pdf_sha256);
}

extractPage364().catch(console.error);
