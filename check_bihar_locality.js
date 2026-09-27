const fs = require('fs');
const path = require('path');

const file = 'D:\\ANTIGRAVITY_WORKSPACE\\INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826\\BIHAR\\Localities_Urban_Localbodies_2026-08-26_23-15-25.xlsx';

if (fs.existsSync(file)) {
    const content = fs.readFileSync(file, 'utf8');
    
    // Check if it's HTML or XML Spreadsheet
    let headers = [];
    let rowCount = 0;
    
    const headerMatch = content.match(/<thead[^>]*>([\s\S]*?)<\/thead>/i) || content.match(/<tr[^>]*>([\s\S]*?)<\/tr>/i);
    if (headerMatch) {
        const thRegex = /<th[^>]*>([\s\S]*?)<\/th>/gi;
        let m;
        while ((m = thRegex.exec(headerMatch[1])) !== null) {
            headers.push(m[1].replace(/<[^>]+>/g, '').trim().replace(/\s+/g, ' '));
        }
    }
    
    const rowsMatch = content.match(/<tr[^>]*>/gi);
    if (rowsMatch) rowCount = rowsMatch.length - 1; // subtract header
    
    console.log(`File: ${path.basename(file)}`);
    console.log(`Headers: ${headers.join(', ')}`);
    console.log(`Data Rows: ${rowCount}`);
} else {
    console.log(`File not found: ${file}`);
}
