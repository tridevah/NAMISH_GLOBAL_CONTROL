const XLSX = require('xlsx');
const pv = XLSX.readFile('D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826/Pincodeto_Village_Mapping_2026-08-26_23-05-48.xlsx', {sheetRows: 2});
console.log('PV Headers:', XLSX.utils.sheet_to_json(pv.Sheets[pv.SheetNames[0]], {header: 1})[0]);
console.log('PV Rows approx:', XLSX.utils.decode_range(pv.Sheets[pv.SheetNames[0]]['!ref']).e.r);
const pu = XLSX.readFile('D:/ANTIGRAVITY_WORKSPACE/INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826/Pincodeto_Urban_Mapping_2026-08-26_23-06-09.xlsx', {sheetRows: 2});
console.log('PU Headers:', XLSX.utils.sheet_to_json(pu.Sheets[pu.SheetNames[0]], {header: 1})[0]);
console.log('PU Rows approx:', XLSX.utils.decode_range(pu.Sheets[pu.SheetNames[0]]['!ref']).e.r);
