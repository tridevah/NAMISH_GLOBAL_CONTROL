const fs = require('fs');
const XLSX = require('xlsx');
const path = require('path');

let buf = fs.readFileSync('C:/Users/Atul1/Downloads/All_Blockof_India_2026-08-30_13-20-20.xlsx');
let wb = XLSX.read(buf, {type: 'buffer'});
let ws = wb.Sheets[wb.SheetNames[0]];
let rows = XLSX.utils.sheet_to_json(ws, {header:1, defval:''});

let headerIdx = rows.findIndex(r => r[0] && String(r[0]).toLowerCase().includes('s.no'));
let data = rows.slice(headerIdx+1).filter(r => String(r[1]) === '12');

// Convert to the exact format of 'Blockofspecific_State'
let newRows = [];
newRows.push(['All Development Blocks of Arunachal Pradesh State', '', '', '', '', '', '']);
newRows.push(['S.No.', 'District Code', 'District Name (In English)', 'Development Block Code', ' Development Block Version', 'Development Block Name (In English)', 'Development Block Name (In Local)']);
for (let i = 0; i < data.length; i++) {
    let r = data[i];
    // S.No, District Code(3), District Name(4), Block Code(5), Block Version(6), Block Name Eng(7), Block Name Local(8)
    newRows.push([i+1, r[3], r[4], r[5], r[6], r[7], r[8]]);
}

let newWs = XLSX.utils.aoa_to_sheet(newRows);
let newWb = XLSX.utils.book_new();
XLSX.utils.book_append_sheet(newWb, newWs, 'Sheet1');
XLSX.writeFile(newWb, 'D:/NAMISH_GLOBAL_CONTROL/scripts/Blockofspecific_State_Arunachal.xlsx');
console.log('Created Blockofspecific_State_Arunachal.xlsx with', data.length, 'rows');
