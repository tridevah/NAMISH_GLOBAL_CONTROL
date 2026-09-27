const fs = require('fs');
const path = require('path');

const root = 'D:\\ANTIGRAVITY_WORKSPACE\\INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826';
const files = [];

function walk(dir) {
    if (!fs.existsSync(dir)) return;
    const list = fs.readdirSync(dir);
    for (const item of list) {
        const fullPath = path.join(dir, item);
        const stat = fs.statSync(fullPath);
        if (stat.isDirectory()) walk(fullPath);
        else if (fullPath.includes('Localities_Urban_Localbodies')) files.push(fullPath);
    }
}
walk(root);

let totalRows = 0;
for (const file of files) {
    const content = fs.readFileSync(file, 'utf8');
    const rowsMatch = content.match(/<tr[^>]*>/gi);
    const rowCount = rowsMatch ? rowsMatch.length - 1 : 0;
    totalRows += rowCount;
    // console.log(`${path.basename(file)}: ${rowCount} rows`);
}
console.log(`Total Locality Files Found: ${files.length}`);
console.log(`Total Data Rows Across All Files: ${totalRows}`);
if (files.length > 0) {
    const content = fs.readFileSync(files[0], 'utf8');
    let headers = [];
    const headerMatch = content.match(/<thead[^>]*>([\s\S]*?)<\/thead>/i) || content.match(/<tr[^>]*>([\s\S]*?)<\/tr>/i);
    if (headerMatch) {
        const thRegex = /<th[^>]*>([\s\S]*?)<\/th>/gi;
        let m;
        while ((m = thRegex.exec(headerMatch[1])) !== null) {
            headers.push(m[1].replace(/<[^>]+>/g, '').trim().replace(/\s+/g, ' '));
        }
    }
    console.log(`Headers: ${headers.join(' | ')}`);
}
