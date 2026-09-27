const AdmZip = require('adm-zip');
const file = 'D:\\ANTIGRAVITY_WORKSPACE\\INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826\\ANDAMAN AND NICOBAR ISLANDS\\downloadDir2026_08_26_23_55_42_288.zip';
const zip = new AdmZip(file);

for (const entry of zip.getEntries()) {
    if (entry.isDirectory) continue;
    const content = entry.getData().toString('utf8');
    
    console.log(`\n--- ${entry.entryName.split('2026')[0]} ---`);
    const rows = content.match(/<Row[^>]*>([\s\S]*?)<\/Row>/gi) || [];
    for (let i=0; i<Math.min(5, rows.length); i++) {
        const cellsMatch = rows[i].match(/<Data[^>]*>([\s\S]*?)<\/Data>/gi);
        if (cellsMatch && cellsMatch.length > 2) {
            const headers = cellsMatch.map(c => c.replace(/<[^>]+>/g, '').trim().replace(/\s+/g, ' ').replace(/&#10;/g, ' ').replace(/&#13;/g, ' '));
            console.log(`Row ${i+1}: ` + headers.join(' | '));
            break;
        }
    }
}
