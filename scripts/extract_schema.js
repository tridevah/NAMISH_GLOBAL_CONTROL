const fs = require('fs');
const text = fs.readFileSync('schema_dump.sql', 'utf8');
const tables = ['jurisdictions', 'tax_rates', 'country_tax_coverage', 'tax_authorities'];
for (const t of tables) {
  const match = text.match(new RegExp('CREATE TABLE IF NOT EXISTS "catalog"."' + t + '" \\([\\s\\S]*?\\);', 'i'));
  if (match) console.log(match[0] + '\n');
}
