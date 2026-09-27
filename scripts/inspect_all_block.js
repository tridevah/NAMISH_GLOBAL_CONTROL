const fs = require('fs');
const XLSX = require('xlsx');

let buf = fs.readFileSync('C:/Users/Atul1/Downloads/All_Blockof_India_2026-08-30_13-20-20.xlsx');
let wb = XLSX.read(buf, {type: 'buffer'});
let ws = wb.Sheets[wb.SheetNames[0]];
let rows = XLSX.utils.sheet_to_json(ws, {header:1, defval:''});
console.log(rows.slice(0, 5));
