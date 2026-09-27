const fs = require('fs');
const XLSX = require('xlsx');

let buf = fs.readFileSync('D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826/ANDHRA PRADESH/blockofspecificState2026-08-27 00-00-29-240.xls');
let wb = XLSX.read(buf, {type: 'buffer'});
let ws = wb.Sheets[wb.SheetNames[0]];
let rows = XLSX.utils.sheet_to_json(ws, {header:1, defval:''});
console.log(rows[0]);
console.log(rows[1]);
console.log(rows[2]);
console.log(rows[3]);
