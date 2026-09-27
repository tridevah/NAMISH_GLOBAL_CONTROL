const { execSync } = require('child_process');
const fs = require('fs');
const result = execSync(`npx supabase db query "SELECT id, official_name FROM catalog.geography_units WHERE country_id = 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d' AND parent_geography_unit_id IS NULL" --linked --output-format json`, { encoding: 'utf8' });
const jsonStr = result.substring(result.indexOf('{'));
const data = JSON.parse(jsonStr).rows;
fs.writeFileSync('india_states_clean.json', JSON.stringify(data, null, 2));
console.log('Cleaned ' + data.length + ' states.');
