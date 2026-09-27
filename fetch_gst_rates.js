const { execSync } = require('child_process');
const fs = require('fs');

console.log('Fetching gst_rate_master...');
const query = `npx supabase db query "SELECT * FROM catalog.gst_rate_master" --linked > gst_rates_out.txt`;
execSync(query);
const raw = fs.readFileSync('gst_rates_out.txt', 'utf8');
const lines = raw.split('\n');
const jsonStr = lines.slice(lines.findIndex(l => l.includes('"rows":')) - 1, lines.findIndex(l => l.includes('"warning"'))).join('\n') + '}\n}';
try {
  const rows = JSON.parse(jsonStr).rows;
  fs.writeFileSync('current_gst_rates.json', JSON.stringify(rows, null, 2));
  console.log('Written to current_gst_rates.json');
} catch (e) {
  console.error("Parse failed");
  // Just dump everything
  fs.writeFileSync('current_gst_rates.json', raw);
}
