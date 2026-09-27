const fs = require('fs');
const path = require('path');
const XLSX = require('xlsx');

function validateXlsx(filePath) {
    let buf = fs.readFileSync(filePath);
    let wb = XLSX.read(buf, {type: 'buffer'});
    let ws = wb.Sheets[wb.SheetNames[0]];
    let rows = XLSX.utils.sheet_to_json(ws, {header:1, defval:''});
    
    let stateCode = null;
    let stateName = null;
    let title = String(rows[1][0]);
    let match = title.match(/All (?:Districts|Sub-districts|Blocks) of (.*?)\(State Code:(\d+)\)/i);
    if (match) {
        stateName = match[1].trim().toUpperCase();
        stateCode = match[2];
    }
    
    let headerIdx = rows.findIndex(r => r[0] && String(r[0]).toLowerCase().includes('s.no') || String(r[0]).toLowerCase().includes('s. no'));
    let header = rows[headerIdx].map(c=>String(c).toLowerCase().trim().replace(/\r?\n/g, ' '));
    let codeIdx = header.findIndex(c => c === 'district code' || c === 'subdistrict code' || c === 'sub-district code' || c === 'block code');
    if(filePath.includes('District')) codeIdx = header.findIndex(c => c === 'district code');
    if(filePath.includes('Sub_District')) codeIdx = header.findIndex(c => c === 'subdistrict code' || c === 'sub-district code');
    if(filePath.includes('Blockofspecific')) codeIdx = header.findIndex(c => c === 'block code');
    
    let data = rows.slice(headerIdx+1).filter(r => r[codeIdx] && !isNaN(parseInt(r[codeIdx])));
    
    console.log(path.basename(filePath));
    console.log('State:', stateName, 'Code:', stateCode);
    console.log('Data Rows:', data.length);
    console.log('First 3 codes:', data.slice(0,3).map(r => r[codeIdx]));
    console.log('---');
}

validateXlsx('C:/Users/Atul1/Downloads/Districtof_Specific_State_2026-08-30_13-21-25.xlsx');
validateXlsx('C:/Users/Atul1/Downloads/Sub_Districtof_Specific_State_2026-08-30_13-20-54.xlsx');
validateXlsx('C:/Users/Atul1/Downloads/Blockofspecific_State_2026-08-30_13-19-19.xlsx');
