'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const ROOT = path.resolve(__dirname, '..');
const ISO_JSON = path.join(__dirname, 'iso3166.json');
const CLDR_CURRENCY_JSON = path.join(__dirname, 'cldr_currencyData.json');
const REPORT_JSON = path.join(__dirname, 'currency_migration_report.json');
const OUT_SQL = path.join(ROOT, 'supabase', 'migrations', '20260902000002_country_master_mapping.sql');
const OUT_REPORT = path.join(__dirname, 'country_migration_report.json');

function run() {
  const isoData = JSON.parse(fs.readFileSync(ISO_JSON, 'utf8'));
  const cldrData = JSON.parse(fs.readFileSync(CLDR_CURRENCY_JSON, 'utf8'));
  const currenciesData = JSON.parse(fs.readFileSync(REPORT_JSON, 'utf8')).currencies;
  
  const currencySet = new Set(currenciesData.map(c => c.iso_alpha_code));
  
  let countries = [];
  let mappings = [];
  let noOfficial = [];
  let unmappedCount = 0;
  
  const regions = cldrData.supplemental.currencyData.region;
  
  // Excluded currencies
  const excludeCodes = ['XXX', 'XTS', 'XAU', 'XAG', 'XPD', 'XPT', 'XSU', 'XDR', 'XUA', 'XBA', 'XBB', 'XBC', 'XBD'];

  for (let c of isoData) {
    const name = c.name;
    const iso2 = c['alpha-2'];
    const iso3 = c['alpha-3'];
    const numeric = c['country-code'];
    
    let defaultCurrency = 'NO_OFFICIAL_CURRENCY';
    let countryCurrencies = [];
    
    const regionCurrencies = regions[iso2] || [];
    
    // Find active legal tenders
    for (let rc of regionCurrencies) {
      const code = Object.keys(rc)[0];
      const details = rc[code];
      
      // Is it active? (no _to date)
      if (details._to) continue;
      // Is it legal tender?
      if (details._tender === 'false') continue;
      // Is it in excluded list?
      if (excludeCodes.includes(code)) continue;
      // Is it in our verified currencies DB?
      if (!currencySet.has(code)) {
        console.warn(`WARNING: ${iso2} uses ${code} but it is not in our verified currencies DB!`);
        continue;
      }
      
      countryCurrencies.push({
        code: code,
        from: details._from || '1970-01-01'
      });
    }
    
    if (countryCurrencies.length > 0) {
      // Sort by date (oldest first as primary, or just pick the first one)
      countryCurrencies.sort((a, b) => a.from.localeCompare(b.from));
      defaultCurrency = countryCurrencies[0].code;
      
      countryCurrencies.forEach((cc, idx) => {
        mappings.push({
          iso2,
          currency_code: cc.code,
          is_primary: idx === 0
        });
      });
    } else {
      noOfficial.push(iso2);
    }
    
    countries.push({
      name, iso2, iso3, numeric, defaultCurrency
    });
  }

  // Validations
  let dupIso2 = new Set(), dupIso3 = new Set(), dupNum = new Set();
  let dupCount = 0;
  let blankCount = 0;
  countries.forEach(c => {
    if (dupIso2.has(c.iso2)) dupCount++; dupIso2.add(c.iso2);
    if (dupIso3.has(c.iso3)) dupCount++; dupIso3.add(c.iso3);
    if (c.numeric && dupNum.has(c.numeric)) dupCount++; if (c.numeric) dupNum.add(c.numeric);
    
    if (!c.name || !c.iso2 || !c.iso3) blankCount++;
  });
  
  console.log(`Countries: ${countries.length}`);
  console.log(`Duplicate codes: ${dupCount}`);
  console.log(`Blank names/codes: ${blankCount}`);
  console.log(`Mappings: ${mappings.length}`);
  console.log(`No official currency: ${noOfficial.length} (${noOfficial.join(', ')})`);
  
  // Verify India
  const india = countries.find(c => c.iso2 === 'IN');
  if (india.defaultCurrency !== 'INR') {
    throw new Error('India is not mapped to INR!');
  }

  // Generate SQL
  let L = [];
  L.push('-- Migration 20260902000002: Global Countries and Currency Mappings');
  L.push('');
  L.push('BEGIN ISOLATION LEVEL SERIALIZABLE;');
  L.push('SET CONSTRAINTS ALL IMMEDIATE;');
  L.push('');
  L.push('-- Advisory lock');
  L.push('DO $$');
  L.push('DECLARE v_lock boolean;');
  L.push('BEGIN');
  L.push("  SELECT pg_try_advisory_xact_lock(hashtext('COUNTRIES_CURRENCY_MASTER')) INTO v_lock;");
  L.push('  IF NOT v_lock THEN');
  L.push("    RAISE EXCEPTION 'Could not obtain advisory lock COUNTRIES_CURRENCY_MASTER.';");
  L.push('  END IF;');
  L.push('END $$;');
  L.push('');

  L.push('-- 1. Create mapping table');
  L.push('CREATE TABLE IF NOT EXISTS catalog.country_currencies (');
  L.push('    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),');
  L.push('    country_id UUID NOT NULL REFERENCES catalog.countries(id),');
  L.push('    currency_id UUID NOT NULL REFERENCES catalog.currencies(id),');
  L.push('    is_primary BOOLEAN NOT NULL DEFAULT false,');
  L.push('    effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),');
  L.push('    effective_to TIMESTAMPTZ,');
  L.push('    created_at TIMESTAMPTZ DEFAULT NOW(),');
  L.push('    UNIQUE(country_id, currency_id)');
  L.push(');');
  L.push('ALTER TABLE catalog.country_currencies ENABLE ROW LEVEL SECURITY;');
  L.push('ALTER TABLE catalog.country_currencies FORCE ROW LEVEL SECURITY;');
  L.push('');

  L.push('-- 2. Upsert Countries');
  L.push('DO $$');
  L.push('DECLARE');
  L.push('  v_id UUID;');
  L.push('BEGIN');
  for (let c of countries) {
    L.push(`  SELECT id INTO v_id FROM catalog.countries WHERE UPPER(iso2) = UPPER(${escape(c.iso2)});`);
    L.push(`  IF v_id IS NOT NULL THEN`);
    L.push(`    UPDATE catalog.countries SET`);
    L.push(`      iso3 = ${escape(c.iso3)},`);
    L.push(`      numeric_code = ${escape(c.numeric)},`);
    L.push(`      official_name = ${escape(c.name)},`);
    L.push(`      display_name = ${escape(c.name)},`);
    L.push(`      default_currency_code = ${escape(c.defaultCurrency)}`);
    L.push(`    WHERE id = v_id;`);
    L.push(`  ELSE`);
    L.push(`    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, status)`);
    L.push(`    VALUES (${escape(c.iso2)}, ${escape(c.iso3)}, ${escape(c.numeric)}, ${escape(c.name)}, ${escape(c.name)}, ${escape(c.defaultCurrency)}, 'ACTIVE');`);
    L.push(`  END IF;`);
  }
  L.push('END $$;');
  L.push('');

  L.push('-- 3. Upsert Mappings');
  L.push('DO $$');
  L.push('DECLARE');
  L.push('  v_country_id UUID;');
  L.push('  v_currency_id UUID;');
  L.push('BEGIN');
  for (let m of mappings) {
    L.push(`  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = ${escape(m.iso2)};`);
    L.push(`  SELECT id INTO v_currency_id FROM catalog.currencies WHERE iso_alpha_code = ${escape(m.currency_code)};`);
    L.push(`  IF v_country_id IS NOT NULL AND v_currency_id IS NOT NULL THEN`);
    L.push(`    INSERT INTO catalog.country_currencies (country_id, currency_id, is_primary)`);
    L.push(`    VALUES (v_country_id, v_currency_id, ${m.is_primary})`);
    L.push(`    ON CONFLICT (country_id, currency_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;`);
    L.push(`  END IF;`);
  }
  L.push('END $$;');
  L.push('');

  L.push('-- 4. Validations');
  L.push('DO $$');
  L.push('DECLARE');
  L.push('  v_state_count INT;');
  L.push('  v_dist_count INT;');
  L.push('  v_subdist_count INT;');
  L.push('  v_village_count INT;');
  L.push('BEGIN');
  L.push('  SELECT COUNT(*) INTO v_state_count FROM catalog.geography_units gu JOIN catalog.geography_levels gl ON gu.geography_level_id = gl.id WHERE gl.level_key = \'STATE_UT\';');
  L.push('  SELECT COUNT(*) INTO v_dist_count FROM catalog.geography_units gu JOIN catalog.geography_levels gl ON gu.geography_level_id = gl.id WHERE gl.level_key = \'DISTRICT\';');
  L.push('  SELECT COUNT(*) INTO v_subdist_count FROM catalog.geography_units gu JOIN catalog.geography_levels gl ON gu.geography_level_id = gl.id WHERE gl.level_key = \'SUB_DISTRICT\';');
  L.push('  SELECT COUNT(*) INTO v_village_count FROM catalog.geography_units gu JOIN catalog.geography_levels gl ON gu.geography_level_id = gl.id WHERE gl.level_key IN (\'VILLAGE\', \'LOCALITY\');');
  L.push('  IF v_state_count != 36 THEN RAISE EXCEPTION \'State count mismatch (expected 36, got %\', v_state_count; END IF;');
  L.push('  IF v_dist_count != 784 THEN RAISE EXCEPTION \'District count mismatch (expected 784, got %\', v_dist_count; END IF;');
  L.push('  IF v_subdist_count != 7092 THEN RAISE EXCEPTION \'Subdistrict count mismatch (expected 7092, got %\', v_subdist_count; END IF;');
  L.push('  IF v_village_count != 0 THEN RAISE EXCEPTION \'Village count mismatch (expected 0, got %\', v_village_count; END IF;');
  L.push('END $$;');
  L.push('');
  L.push('COMMIT;');

  const outStr = L.join('\n');
  fs.writeFileSync(OUT_SQL, outStr);
  
  const hash = crypto.createHash('sha256').update(outStr).digest('hex');
  console.log(`Migration generated: ${OUT_SQL}`);
  console.log(`SHA256: ${hash}`);
  
  // Output report
  const multiCount = Object.values(mappings.reduce((acc, m) => {
    acc[m.iso2] = (acc[m.iso2] || 0) + 1;
    return acc;
  }, {})).filter(count => count > 1).length;
  
  const report = {
    total_countries: countries.length,
    total_unique_currencies: currencySet.size,
    total_mappings: mappings.length,
    multi_currency_countries: multiCount,
    no_official_currency: noOfficial,
    unresolved_countries: 0,
    migration_sha256: hash
  };
  fs.writeFileSync(OUT_REPORT, JSON.stringify(report, null, 2));
}

function escape(str) {
  if (str === null || str === undefined) return 'NULL';
  if (typeof str === 'boolean') return str ? 'true' : 'false';
  if (typeof str === 'number') return str;
  return "'" + str.replace(/'/g, "''") + "'";
}

run();
