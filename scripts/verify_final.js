const { execSync } = require('child_process');

function query(sql) {
  const result = execSync(`npx supabase db query "${sql}" --linked --output-format json`, { encoding: 'utf8' });
  const idx = result.indexOf('{');
  if (idx > -1) {
    const jsonStr = result.substring(idx);
    try {
      return JSON.parse(jsonStr).rows;
    } catch(e) {
      console.error('Failed to parse:', jsonStr);
      return [];
    }
  }
  return [];
}

console.log('--- VERIFICATION SCRIPT ---');

const ledger = query("SELECT count(*) as c FROM supabase_migrations.schema_migrations WHERE version = '20260902000004'");
console.log('Ledger records (exactly once):', ledger[0].c);

const covTotal = query("SELECT count(*) as c FROM catalog.country_tax_coverage");
console.log('Total coverage rows (assert 249):', covTotal[0].c);
const covStats = query("SELECT status, count(*) as c FROM catalog.country_tax_coverage GROUP BY status ORDER BY status");
console.log('Coverage breakdowns (47 VERIFIED, 1 NOT_APPLICABLE, 201 UNRESOLVED):', covStats);

const authTotal = query("SELECT count(*) as c FROM catalog.tax_authorities");
console.log('Total tax authorities (assert 47):', authTotal[0].c);

const invalidType = query("SELECT count(*) as c FROM catalog.tax_authorities WHERE tax_type NOT IN ('GST', 'VAT', 'SALES_TAX', 'WITHHOLDING', 'TDS', 'CUSTOMS', 'EXCISE')");
console.log('Invalid tax types (assert 0):', invalidType[0].c);
const overlaps = query("SELECT COUNT(*) as c FROM catalog.tax_authorities a1 JOIN catalog.tax_authorities a2 ON a1.id != a2.id AND a1.country_id = a2.country_id AND a1.tax_type = a2.tax_type AND (a1.effective_from <= a2.effective_to OR a2.effective_to IS NULL) AND (a2.effective_from <= a1.effective_to OR a1.effective_to IS NULL)");
console.log('Overlaps (assert 0):', overlaps[0].c);
const dupes = query("SELECT COUNT(*) as c FROM (SELECT country_id, tax_type, COUNT(*) FROM catalog.tax_authorities GROUP BY country_id, tax_type HAVING COUNT(*) > 1) d");
console.log('Exact Duplicates (assert 0):', dupes[0].c);

const countries = query("SELECT count(*) as c FROM catalog.countries");
console.log('Total countries (Geography):', countries[0].c);
const currencies = query("SELECT count(*) as c FROM catalog.currencies");
console.log('Total currencies (Currency):', currencies[0].c);
const r16Blocks = query("SELECT count(*) as c FROM catalog.development_blocks");
console.log('Total R16 blocks:', r16Blocks[0].c);
