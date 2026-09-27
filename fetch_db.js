const fs = require('fs');
const { execSync } = require('child_process');

console.log('Fetching HSN...');
// Let's use pg client directly since we have connection string, or just use psql via npx supabase
const queryHsn = `npx supabase db query "SELECT code_type, code, description, parent_code, classification_level FROM catalog.hsn_sac WHERE code_type='HSN' AND country_id=(SELECT id FROM catalog.countries WHERE iso2='IN') AND status='ACTIVE'" --linked`;
// Exec with redirect to avoid ENOBUFS
execSync(`${queryHsn} > hsn_out.txt`);
const hsnStr = fs.readFileSync('hsn_out.txt', 'utf8');
const hsn = JSON.parse(hsnStr).rows;
fs.writeFileSync('db_hsn_export.json', JSON.stringify(hsn, null, 2), 'utf8');

console.log('Fetching SAC...');
const querySac = `npx supabase db query "SELECT code_type, code, description, parent_code, classification_level FROM catalog.hsn_sac WHERE code_type='SAC' AND country_id=(SELECT id FROM catalog.countries WHERE iso2='IN') AND status='ACTIVE'" --linked`;
execSync(`${querySac} > sac_out.txt`);
const sacStr = fs.readFileSync('sac_out.txt', 'utf8');
const sac = JSON.parse(sacStr).rows;
fs.writeFileSync('db_sac_export.json', JSON.stringify(sac, null, 2), 'utf8');

console.log('Done.');
