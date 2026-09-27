const fs = require('fs');
const path = require('path');
const AdmZip = require('adm-zip');

const root = 'D:\\ANTIGRAVITY_WORKSPACE\\INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826';
let file = null;

function walk(dir) {
    if (!fs.existsSync(dir)) return;
    const list = fs.readdirSync(dir);
    for (const item of list) {
        const fullPath = path.join(dir, item);
        const stat = fs.statSync(fullPath);
        if (stat.isDirectory()) walk(fullPath);
        else if (fullPath.includes('MAHARASHTRA\\Localities_Urban_Localbodies') && !file) file = fullPath;
    }
}
walk(root);

console.log('Reading:', file);
if (file) {
    const zip = new AdmZip(file);
    const sheet = zip.getEntry('xl/worksheets/sheet1.xml').getData().toString('utf8');
    const sharedStrings = zip.getEntry('xl/sharedStrings.xml').getData().toString('utf8');
    const strings = (sharedStrings.match(/<t(?:[^>]*)>([\s\S]*?)<\/t>/g) || []).map(m => m.replace(/<[^>]+>/g, '').trim());

    const rows = sheet.match(/<row[^>]*>([\s\S]*?)<\/row>/g) || [];
    rows.forEach((row, idx) => {
        const cells = row.match(/<c[^>]*>[\s\S]*?<\/c>/g) || [];
        const vals = cells.map(c => {
            const v = c.match(/<v>([\s\S]*?)<\/v>/);
            if (!v) return '';
            return c.includes('t="s"') ? strings[parseInt(v[1])] : v[1];
        });
        console.log(`Row ${idx}:`, vals.join(' | '));
    });
}
