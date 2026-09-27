const fs = require('fs');
const XLSX = require('xlsx');

let buf = fs.readFileSync('C:/Users/Atul1/Downloads/All_Blockof_India_2026-08-30_13-20-20.xlsx');
let wb = XLSX.read(buf, {type: 'buffer'});
let ws = wb.Sheets[wb.SheetNames[0]];
let rows = XLSX.utils.sheet_to_json(ws, {header:1, defval:''});
let headerIdx = rows.findIndex(r => r[0] && String(r[0]).toLowerCase().includes('s.no') || String(r[0]).toLowerCase().includes('s. no'));
let header = rows[headerIdx].map(c=>String(c).toLowerCase().trim().replace(/\r?\n/g, ' '));
let codeIdx = header.findIndex(c => c.includes('block code'));
let data = rows.slice(headerIdx+1).filter(r => r[codeIdx] && !isNaN(parseInt(r[codeIdx])));
console.log('Total blocks in All_Blockof_India:', data.length);
