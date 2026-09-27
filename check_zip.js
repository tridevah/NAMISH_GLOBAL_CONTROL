const AdmZip = require('adm-zip');
const fs = require('fs');

const zipPath = 'D:\\ANTIGRAVITY_WORKSPACE\\INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826\\GOA\\downloadDir2026_08_27_00_03_28_787.zip';
const zip = new AdmZip(zipPath);
const entries = zip.getEntries();

for (const entry of entries) {
    if (!entry.isDirectory) {
        const content = entry.getData().toString('utf8');
        let headers = [];
        const headerMatch = content.match(/<thead[^>]*>([\s\S]*?)<\/thead>/i) || content.match(/<tr[^>]*>([\s\S]*?)<\/tr>/i);
        if (headerMatch) {
            const thRegex = /<th[^>]*>([\s\S]*?)<\/th>/gi;
            let m;
            while ((m = thRegex.exec(headerMatch[1])) !== null) {
                headers.push(m[1].replace(/<[^>]+>/g, '').trim().replace(/\s+/g, ' '));
            }
        }
        
        let rowCount = 0;
        const rowsMatch = content.match(/<tr[^>]*>/gi);
        if (rowsMatch) rowCount = rowsMatch.length - 1; // subtract header
        
        console.log(`File: ${entry.entryName} | Rows: ${rowCount} | Headers: ${headers.slice(0,6).join(', ')}`);
    }
}
