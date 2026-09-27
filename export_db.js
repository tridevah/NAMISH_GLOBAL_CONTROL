const fs = require('fs');
const { execSync } = require('child_process');

const hsnOut = execSync('npx supabase db query "SELECT code_type, code, description, parent_code, classification_level FROM catalog.hsn_sac WHERE code_type=\'HSN\' AND country_id=(SELECT id FROM catalog.countries WHERE iso2=\'IN\') AND status=\'ACTIVE\'" --linked', {encoding: 'utf8'});
const hsnData = JSON.parse(hsnOut).rows;
fs.writeFileSync('db_hsn_export.json', JSON.stringify(hsnData, null, 2), 'utf8');

const sacOut = execSync('npx supabase db query "SELECT code_type, code, description, parent_code, classification_level FROM catalog.hsn_sac WHERE code_type=\'SAC\' AND country_id=(SELECT id FROM catalog.countries WHERE iso2=\'IN\') AND status=\'ACTIVE\'" --linked', {encoding: 'utf8'});
const sacData = JSON.parse(sacOut).rows;
fs.writeFileSync('db_sac_export.json', JSON.stringify(sacData, null, 2), 'utf8');
