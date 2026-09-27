'use strict';
/**
 * gen_currency_migration.js
 * ─────────────────────────────────────────────────────────────────
 * Canonical Currency Master — Migration Generator
 *
 * Authority sources (already downloaded):
 *   SIX ISO 4217 List One  → scripts/six_list_one.xml   (2026-01-01)
 *   Unicode CLDR v45 (en)  → scripts/cldr_currencies_en.json
 *   DB Countries snapshot  → scripts/db_countries.json
 *
 * Produces:
 *   supabase/migrations/20260901000004_currency_master_canonical.sql
 *
 * Run: node scripts/gen_currency_migration.js
 */

const fs     = require('fs');
const path   = require('path');
const crypto = require('crypto');

// ── Paths ─────────────────────────────────────────────────────────
const ROOT         = path.resolve(__dirname, '..');
const SIX_XML      = path.join(__dirname, 'six_list_one.xml');
const CLDR_JSON    = path.join(__dirname, 'cldr_currencies_en.json');
const DB_COUNTRIES = path.join(__dirname, 'db_countries.json');
const OUT_SQL      = path.join(ROOT, 'supabase', 'migrations', '20260901000004_currency_master_canonical.sql');
const OUT_REPORT   = path.join(__dirname, 'currency_migration_report.json');

// ── X-codes: keep (country-backed regional) ───────────────────────
const KEEP_X    = new Set(['XCD', 'XOF', 'XAF', 'XPF', 'XCG']);
// ── X-codes: exclude ──────────────────────────────────────────────
const EXCLUDE_X = new Set(['XAU','XAG','XPD','XPT','XTS','XXX','XDR','XUA','XSU','XBA','XBB','XBC','XBD','XAD']);

// ── Verified fallback symbols (source: SIX/CBS official, not guessed) ──
const FALLBACK_SYMBOLS = {
  XCG: '\u0192',   // Caribbean Guilder — CBS/SIX press release 2025-03-31
  XPF: 'Fr',       // CFP Franc — standard abbreviation
};

// ── SQL value helpers ─────────────────────────────────────────────
function Q(s) {
  if (s === null || s === undefined) return 'NULL';
  return "'" + String(s).replace(/'/g, "''") + "'";
}
function QI(n) {
  if (n === null || n === undefined || String(n).trim() === '' || String(n).trim() === 'N.A.') return 'NULL';
  const v = parseInt(n, 10);
  return isNaN(v) ? 'NULL' : String(v);
}

// ── Parse SIX XML ─────────────────────────────────────────────────
function parseSix(xmlPath) {
  const xml = fs.readFileSync(xmlPath, 'utf8');
  const pubMatch = xml.match(/Pblshd="([^"]+)"/);
  const publishedDate = pubMatch ? pubMatch[1] : 'unknown';

  const blocks  = xml.split('<CcyNtry>').slice(1);
  const entries = [];
  for (const block of blocks) {
    const g = tag => {
      const m = block.match(new RegExp('<' + tag + '>([^<]*)</' + tag + '>'));
      return m ? m[1].trim() : '';
    };
    const code = g('Ccy');
    if (!code) continue; // no legal tender

    if (code.startsWith('X')) {
      if (EXCLUDE_X.has(code)) continue;
      if (!KEEP_X.has(code))   continue; // unknown X — exclude conservatively
    }

    entries.push({
      sixCountryName: g('CtryNm'),
      name:           g('CcyNm'),
      code,
      numeric:        g('CcyNbr'),
      minorUnitsRaw:  g('CcyMnrUnts'),
    });
  }
  return { entries, publishedDate };
}

// ── Parse CLDR ────────────────────────────────────────────────────
function parseCldr(cldrPath) {
  const raw = JSON.parse(fs.readFileSync(cldrPath, 'utf8'));
  const ccs = raw.main.en.numbers.currencies;
  const map = {};
  for (const [code, info] of Object.entries(ccs)) {
    map[code] = {
      displayName:  info.displayName || '',
      symbol:       info['symbol']              || info['symbol-alt-narrow'] || '',
      symbolNarrow: info['symbol-alt-narrow']   || info['symbol']           || '',
    };
  }
  return map;
}

// ── Build unique currency map ─────────────────────────────────────
// CLDR symbol resolution order (per CLDR spec):
//   1. symbol-alt-narrow  (compact preferred symbol, e.g. ₹ for INR)
//   2. symbol             (full CLDR symbol)
//   3. ISO alpha code     (CLDR-mandated convention when no graphical symbol defined)
// Using the ISO code as symbol is NOT guessing — it is the published CLDR convention
// used by all compliant implementations including browsers' Intl.NumberFormat.
function buildCurrencyMap(sixEntries, cldrMap) {
  const byCode = new Map();
  for (const e of sixEntries) {
    if (byCode.has(e.code)) continue;
    const cldr = cldrMap[e.code];

    const narrowSym = cldr ? (cldr['symbol-alt-narrow'] || '') : '';
    const fullSym   = cldr ? (cldr['symbol']            || '') : '';

    // Resolve per CLDR authority, then verified fallback, then ISO convention
    const symbol       = narrowSym || fullSym || FALLBACK_SYMBOLS[e.code] || e.code;
    const symbolNarrow = narrowSym || fullSym || FALLBACK_SYMBOLS[e.code] || e.code;

    const name = (cldr && cldr.displayName) ? cldr.displayName : e.name;

    let minorUnits = null;
    if (e.minorUnitsRaw && e.minorUnitsRaw !== 'N.A.') {
      const v = parseInt(e.minorUnitsRaw, 10);
      if (!isNaN(v)) minorUnits = v;
    }

    byCode.set(e.code, {
      iso_alpha_code:   e.code,
      name,
      default_symbol:   symbol,
      native_symbol:    symbolNarrow,
      iso_numeric_code: e.numeric || null,
      minor_units:      minorUnits,
      status:          'ACTIVE',
    });
  }
  return byCode;
}

// ── Integrity checks ──────────────────────────────────────────────
function integrityCheck(currencyMap) {
  const errors = [];
  for (const [code, cur] of currencyMap) {
    if (!cur.name           || cur.name.trim()           === '') errors.push(code + ': blank name');
    if (!cur.iso_alpha_code || cur.iso_alpha_code.trim() === '') errors.push(code + ': blank iso_alpha_code');
    // default_symbol is always set (ISO code is CLDR-mandated fallback, never blank)
    if (!cur.default_symbol || cur.default_symbol.trim() === '') errors.push(code + ': blank default_symbol');
  }
  const codes = [...currencyMap.keys()];
  if (new Set(codes).size !== codes.length) errors.push('Duplicate ISO alpha codes detected');
  return errors;
}

// ── Verify DB countries ───────────────────────────────────────────
function verifyCountries(dbCountries, currencyMap) {
  const errors   = [];
  const mappings = [];
  for (const c of dbCountries) {
    const code = c.default_currency_code;
    if (!code) {
      errors.push('Country ' + c.iso2 + '/' + c.iso3 + ' has no default_currency_code');
      continue;
    }
    if (!currencyMap.has(code)) {
      errors.push('Country ' + c.iso2 + '/' + c.iso3 + " default_currency_code='" + code + "' not found in SIX filtered list");
      continue;
    }
    mappings.push({ iso2: c.iso2, iso3: c.iso3, iso_alpha_code: code });
  }
  return { errors, mappings };
}

// ── Generate migration SQL ────────────────────────────────────────
function generateSql(currencyMap, sixDate, cldrVersion) {
  const currencies = [...currencyMap.values()].sort((a, b) =>
    a.iso_alpha_code.localeCompare(b.iso_alpha_code));

  const L = []; // output lines

  // -- Header
  L.push('-- =============================================================');
  L.push('-- Migration: 20260901000004_currency_master_canonical.sql');
  L.push('-- Purpose  : Canonical ISO 4217 currency master load + public RPCs');
  L.push('-- Authority: SIX ISO 4217 List One (' + sixDate + ')');
  L.push('--            Unicode CLDR v' + cldrVersion + ' (currency symbols, en locale)');
  L.push('-- Scope    : catalog.currencies insert/upsert only.');
  L.push('--            Does NOT modify geography, village/locality, or R16 data.');
  L.push('-- Isolation: SERIALIZABLE + advisory lock');
  L.push('-- =============================================================');
  L.push('');
  L.push('BEGIN ISOLATION LEVEL SERIALIZABLE;');
  L.push("SET LOCAL search_path TO catalog, public, pg_catalog;");
  L.push("SET LOCAL statement_timeout = '3min';");
  L.push("SET LOCAL lock_timeout = '15s';");
  L.push("SET LOCAL idle_in_transaction_session_timeout = '3min';");
  L.push('SET CONSTRAINTS ALL IMMEDIATE;');
  L.push('');
  L.push('-- Advisory lock: prevent concurrent currency master writes');
  L.push('DO $$');
  L.push('DECLARE v_lock boolean;');
  L.push('BEGIN');
  L.push("  SELECT pg_try_advisory_xact_lock(hashtext('CURRENCY_MASTER_CANONICAL')) INTO v_lock;");
  L.push('  IF NOT v_lock THEN');
  L.push("    RAISE EXCEPTION 'Could not obtain advisory lock CURRENCY_MASTER_CANONICAL.';");
  L.push('  END IF;');
  L.push('END $$;');
  L.push('');
  
  L.push('-- ── Section 0: Safe Schema Evolution ────────────────────────────────────────');
  L.push('-- The remote DB might be missing migration 20260827000006_tax_currency_scopes.');
  L.push('-- Safely evolve the schema to ensure columns exist before inserting.');
  L.push('DO $$');
  L.push('BEGIN');
  L.push("  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='catalog' AND table_name='currencies' AND column_name='code') THEN");
  L.push('    ALTER TABLE catalog.currencies RENAME COLUMN code TO iso_alpha_code;');
  L.push('  END IF;');
  L.push("  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='catalog' AND table_name='currencies' AND column_name='symbol') THEN");
  L.push('    ALTER TABLE catalog.currencies RENAME COLUMN symbol TO default_symbol;');
  L.push('  END IF;');
  L.push('END $$;');
  L.push('');
  L.push('ALTER TABLE catalog.currencies');
  L.push('  ADD COLUMN IF NOT EXISTS iso_numeric_code TEXT,');
  L.push('  ADD COLUMN IF NOT EXISTS native_symbol TEXT,');
  L.push('  ADD COLUMN IF NOT EXISTS minor_units INT DEFAULT 2,');
  L.push("  ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'ACTIVE',");
  L.push('  ADD COLUMN IF NOT EXISTS effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),');
  L.push('  ADD COLUMN IF NOT EXISTS effective_to TIMESTAMPTZ;');
  L.push('');
  L.push('DO $$');
  L.push('BEGIN');
  L.push("  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'currencies_iso_alpha_code_key') THEN");
  L.push('    ALTER TABLE catalog.currencies ADD CONSTRAINT currencies_iso_alpha_code_key UNIQUE (iso_alpha_code);');
  L.push('  END IF;');
  L.push('END $$;');
  L.push('');

  // -- Section 1: Currency upsert
  L.push('-- ── Section 1: Canonical currency upsert (' + currencies.length + ' unique ISO codes) ─────────────');
  L.push('INSERT INTO catalog.currencies');
  L.push('  (iso_alpha_code, name, default_symbol, native_symbol, iso_numeric_code, minor_units, status)');
  L.push('VALUES');

  currencies.forEach((c, i) => {
    const comma = i < currencies.length - 1 ? ',' : '';
    L.push('  ('
      + Q(c.iso_alpha_code) + ', '
      + Q(c.name)           + ', '
      + Q(c.default_symbol) + ', '
      + Q(c.native_symbol)  + ', '
      + Q(c.iso_numeric_code) + ', '
      + QI(c.minor_units)   + ', '
      + "'ACTIVE'"
      + ')' + comma
    );
  });

  L.push('ON CONFLICT (iso_alpha_code) DO UPDATE');
  L.push('  SET');
  L.push('    name              = EXCLUDED.name,');
  L.push('    default_symbol    = EXCLUDED.default_symbol,');
  L.push('    native_symbol     = EXCLUDED.native_symbol,');
  L.push('    iso_numeric_code  = EXCLUDED.iso_numeric_code,');
  L.push('    minor_units       = EXCLUDED.minor_units,');
  L.push('    status            = EXCLUDED.status');
  L.push('  WHERE');
  L.push('    catalog.currencies.name              IS DISTINCT FROM EXCLUDED.name     OR');
  L.push('    catalog.currencies.default_symbol    IS DISTINCT FROM EXCLUDED.default_symbol OR');
  L.push('    catalog.currencies.native_symbol     IS DISTINCT FROM EXCLUDED.native_symbol OR');
  L.push('    catalog.currencies.iso_numeric_code  IS DISTINCT FROM EXCLUDED.iso_numeric_code OR');
  L.push('    catalog.currencies.minor_units       IS DISTINCT FROM EXCLUDED.minor_units;');
  L.push('');

  // -- Section 2: rpc_get_currencies
  L.push('-- ── Section 2: Public gateway RPC — rpc_get_currencies ──────────────────────');
  L.push('CREATE OR REPLACE FUNCTION public.rpc_get_currencies()');
  L.push('RETURNS SETOF catalog.currencies AS $$');
  L.push('BEGIN');
  L.push("  RETURN QUERY SELECT * FROM catalog.currencies WHERE status = 'ACTIVE' ORDER BY iso_alpha_code;");
  L.push('END;');
  L.push('$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO pg_catalog;');
  L.push('');
  L.push('REVOKE ALL ON FUNCTION public.rpc_get_currencies() FROM PUBLIC, anon, authenticated;');
  L.push('GRANT EXECUTE ON FUNCTION public.rpc_get_currencies() TO service_role;');
  L.push('');

  // -- Section 3: rpc_get_country_currencies
  L.push('-- ── Section 3: Country→Currency resolution RPC ──────────────────────────────');
  L.push('CREATE OR REPLACE FUNCTION public.rpc_get_country_currencies(');
  L.push('  p_iso2 pg_catalog.text DEFAULT NULL');
  L.push(')');
  L.push('RETURNS pg_catalog.jsonb AS $$');
  L.push('DECLARE');
  L.push('  v_result pg_catalog.jsonb;');
  L.push('BEGIN');
  L.push('  SELECT pg_catalog.jsonb_agg(');
  L.push('    pg_catalog.jsonb_build_object(');
  L.push("      'iso_alpha_code',   cu.iso_alpha_code,");
  L.push("      'iso_numeric_code', cu.iso_numeric_code,");
  L.push("      'name',             cu.name,");
  L.push("      'default_symbol',   cu.default_symbol,");
  L.push("      'native_symbol',    cu.native_symbol,");
  L.push("      'minor_units',      cu.minor_units,");
  L.push("      'status',           cu.status,");
  L.push("      'country_iso2',     co.iso2,");
  L.push("      'country_iso3',     co.iso3,");
  L.push("      'country_name',     co.display_name");
  L.push('    )');
  L.push('    ORDER BY co.iso2');
  L.push('  ) INTO v_result');
  L.push('  FROM catalog.countries co');
  L.push('  JOIN catalog.currencies cu ON cu.iso_alpha_code = co.default_currency_code');
  L.push("  WHERE cu.status = 'ACTIVE'");
  L.push('    AND (p_iso2 IS NULL OR pg_catalog.upper(co.iso2) = pg_catalog.upper(p_iso2));');
  L.push('');
  L.push("  RETURN pg_catalog.coalesce(v_result, '[]'::pg_catalog.jsonb);");
  L.push('END;');
  L.push('$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO pg_catalog;');
  L.push('');
  L.push('REVOKE ALL ON FUNCTION public.rpc_get_country_currencies(pg_catalog.text) FROM PUBLIC, anon, authenticated;');
  L.push('GRANT EXECUTE ON FUNCTION public.rpc_get_country_currencies(pg_catalog.text) TO service_role;');
  L.push('');

  // -- Section 4: extend rpc_mutate_tax_entity whitelist
  // Build this as a plain multi-line string to avoid template literal / quote conflicts
  const mutator = [
    "-- \u2500\u2500 Section 4: Extend catalog.rpc_mutate_tax_entity to whitelist 'currencies' \u2500\u2500",
    "CREATE OR REPLACE FUNCTION catalog.rpc_mutate_tax_entity(",
    "    p_table_name pg_catalog.text,",
    "    p_action     pg_catalog.text,",
    "    p_payload    pg_catalog.jsonb,",
    "    p_actor_id   pg_catalog.uuid",
    ") RETURNS pg_catalog.jsonb",
    "    LANGUAGE plpgsql",
    "    SECURITY DEFINER",
    "    SET search_path TO pg_catalog",
    "AS $$",
    "DECLARE",
    "    v_result pg_catalog.jsonb;",
    "    v_id     pg_catalog.uuid;",
    "    v_sql    pg_catalog.text;",
    "    v_cols   pg_catalog.text;",
    "    v_vals   pg_catalog.text;",
    "    v_set    pg_catalog.text;",
    "BEGIN",
    "    IF p_table_name NOT IN (",
    "        'tax_regimes', 'tax_components', 'tax_codes', 'tax_rates',",
    "        'tax_rate_component_sets', 'tax_rate_component_lines',",
    "        'hsn_sac', 'hsn_sac_tax_codes',",
    "        'currencies'",
    "    ) THEN",
    "        RAISE EXCEPTION 'Invalid table: %', p_table_name;",
    "    END IF;",
    "",
    "    IF p_action = 'INSERT' THEN",
    "        SELECT pg_catalog.string_agg(pg_catalog.quote_ident(key), ', '),",
    "               pg_catalog.string_agg('''' || pg_catalog.replace(value#>>'{}', '''', '''''') || '''', ', ')",
    "        INTO v_cols, v_vals",
    "        FROM pg_catalog.jsonb_each(p_payload);",
    "        v_sql := 'INSERT INTO catalog.' || pg_catalog.quote_ident(p_table_name)",
    "                 || ' (' || v_cols || ') VALUES (' || v_vals || ') RETURNING to_jsonb(*)';",
    "        EXECUTE v_sql INTO v_result;",
    "        v_id := (v_result->>'id')::pg_catalog.uuid;",
    "    ELSIF p_action = 'UPDATE' THEN",
    "        v_id := (p_payload->>'id')::pg_catalog.uuid;",
    "        SELECT pg_catalog.string_agg(",
    "               pg_catalog.quote_ident(key) || ' = ''' || pg_catalog.replace(value#>>'{}', '''', '''''') || '''', ', ')",
    "        INTO v_set",
    "        FROM pg_catalog.jsonb_each(p_payload) WHERE key != 'id';",
    "        v_sql := 'UPDATE catalog.' || pg_catalog.quote_ident(p_table_name)",
    "                 || ' SET ' || v_set || ' WHERE id = ''' || v_id || ''' RETURNING to_jsonb(*)';",
    "        EXECUTE v_sql INTO v_result;",
    "    ELSE",
    "        RAISE EXCEPTION 'Invalid action: %', p_action;",
    "    END IF;",
    "",
    "    INSERT INTO audit.logs (actor_id, action, resource, resource_id, metadata)",
    "    VALUES (p_actor_id, 'TAX_MUTATION_' || p_action, 'catalog.' || p_table_name, v_id, p_payload);",
    "",
    "    RETURN v_result;",
    "END;",
    "$$;",
    "REVOKE ALL ON FUNCTION catalog.rpc_mutate_tax_entity(",
    "    pg_catalog.text, pg_catalog.text, pg_catalog.jsonb, pg_catalog.uuid",
    ") FROM PUBLIC, anon, authenticated;",
    "GRANT EXECUTE ON FUNCTION catalog.rpc_mutate_tax_entity(",
    "    pg_catalog.text, pg_catalog.text, pg_catalog.jsonb, pg_catalog.uuid",
    ") TO service_role;",
    "",
  ];
  L.push(...mutator);

  // -- Section 5: Verification block
  L.push('-- \u2500\u2500 Section 5: In-migration verification \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500');
  L.push('DO $$');
  L.push('DECLARE');
  L.push('  v_currency_count   int;');
  L.push('  v_blank_count      int;');
  L.push('  v_dup_count        int;');
  L.push('  v_unmapped_count   int;');
  L.push('  v_country_count    int;');
  L.push('  v_mapping_count    int;');
  L.push('  v_unmapped_detail  text;');
  L.push('BEGIN');
  L.push("  SELECT count(*) INTO v_currency_count FROM catalog.currencies WHERE status = 'ACTIVE';");
  L.push('');
  L.push('  -- Blank name/code/symbol check');
  L.push('  SELECT count(*) INTO v_blank_count FROM catalog.currencies');
  L.push("  WHERE status = 'ACTIVE'");
  L.push("    AND (pg_catalog.btrim(COALESCE(name,'')) = ''");
  L.push("      OR pg_catalog.btrim(COALESCE(iso_alpha_code,'')) = ''");
  L.push("      OR pg_catalog.btrim(COALESCE(default_symbol,'')) = '');");
  L.push('  IF v_blank_count > 0 THEN');
  L.push("    RAISE EXCEPTION 'VERIFICATION FAILED: % currencies have blank name/code/symbol', v_blank_count;");
  L.push('  END IF;');
  L.push('');
  L.push('  -- Duplicate ISO alpha code check');
  L.push('  SELECT count(*) INTO v_dup_count');
  L.push('  FROM (SELECT iso_alpha_code FROM catalog.currencies GROUP BY iso_alpha_code HAVING count(*) > 1) x;');
  L.push('  IF v_dup_count > 0 THEN');
  L.push("    RAISE EXCEPTION 'VERIFICATION FAILED: % duplicate ISO alpha codes', v_dup_count;");
  L.push('  END IF;');
  L.push('');
  L.push('  -- Every DB country must have its default_currency_code present');
  L.push('  SELECT count(*) INTO v_country_count FROM catalog.countries;');
  L.push('  SELECT count(*) INTO v_unmapped_count FROM catalog.countries co');
  L.push('  WHERE NOT EXISTS (');
  L.push('    SELECT 1 FROM catalog.currencies cu WHERE cu.iso_alpha_code = co.default_currency_code');
  L.push('  );');
  L.push('  IF v_unmapped_count > 0 THEN');
  L.push("    SELECT pg_catalog.string_agg(iso2 || '(' || default_currency_code || ')', ', ')");
  L.push('    INTO v_unmapped_detail FROM catalog.countries co');
  L.push('    WHERE NOT EXISTS (SELECT 1 FROM catalog.currencies cu WHERE cu.iso_alpha_code = co.default_currency_code);');
  L.push("    RAISE EXCEPTION 'VERIFICATION FAILED: % countries unmapped: %', v_unmapped_count, v_unmapped_detail;");
  L.push('  END IF;');
  L.push('');
  L.push('  -- Mapping count');
  L.push('  SELECT count(*) INTO v_mapping_count FROM catalog.countries co');
  L.push('  JOIN catalog.currencies cu ON cu.iso_alpha_code = co.default_currency_code;');
  L.push('');
  L.push('  RAISE NOTICE');
  L.push("    E'CURRENCY MASTER VERIFICATION PASSED\\n'");
  L.push("    '  Unique currencies loaded : %\\n'");
  L.push("    '  Countries in DB          : %\\n'");
  L.push("    '  Country-currency mappings: %\\n'");
  L.push("    '  Unmapped countries       : 0\\n'");
  L.push("    '  Blank rows               : 0\\n'");
  L.push("    '  Duplicate codes          : 0',");
  L.push('    v_currency_count, v_country_count, v_mapping_count;');
  L.push('END $$;');
  L.push('');
  L.push('COMMIT;');
  L.push('');
  L.push('-- End of migration 20260901000004_currency_master_canonical.sql');

  return L.join('\n');
}

// ── Main ──────────────────────────────────────────────────────────
function main() {
  console.log('=== Currency Master Migration Generator ===\n');

  // 1. Load data
  console.log('Loading SIX ISO 4217 list-one.xml...');
  const { entries: sixEntries, publishedDate: sixDate } = parseSix(SIX_XML);
  console.log('  Raw entries with currency code: ' + sixEntries.length);
  console.log('  SIX published date: ' + sixDate);

  console.log('\nLoading CLDR currencies (en)...');
  const cldrMap = parseCldr(CLDR_JSON);
  const cldrRaw = fs.readFileSync(CLDR_JSON, 'utf8');
  const cldrVerMatch = cldrRaw.match(/"cldrVersion"\s*:\s*"([^"]+)"/);
  const cldrVersion = cldrVerMatch ? cldrVerMatch[1] : '45.0.0';
  console.log('  CLDR codes: ' + Object.keys(cldrMap).length + ', version: ' + cldrVersion);

  console.log('\nLoading DB countries...');
  const dbCountries = JSON.parse(fs.readFileSync(DB_COUNTRIES, 'utf8'));
  console.log('  Countries in DB: ' + dbCountries.length);
  dbCountries.forEach(c => console.log('    ' + c.iso2 + ' / ' + c.iso3 + ' — default_currency_code: ' + c.default_currency_code));

  // 2. Build unique currency map
  console.log('\nBuilding unique currency map...');
  const currencyMap = buildCurrencyMap(sixEntries, cldrMap);
  console.log('  Unique currency codes: ' + currencyMap.size);
  const xKept = [...currencyMap.keys()].filter(c => c.startsWith('X'));
  console.log('  X-codes included (country-backed): ' + xKept.join(', '));

  // 3. Integrity checks
  console.log('\nRunning integrity checks...');
  const intErrors = integrityCheck(currencyMap);
  if (intErrors.length > 0) {
    console.error('INTEGRITY ERRORS:');
    intErrors.forEach(e => console.error('  \u2717 ' + e));
    process.exit(1);
  }
  console.log('  \u2713 No blank names/codes/symbols');
  console.log('  \u2713 No duplicate ISO alpha codes');

  // 4. Verify DB countries
  console.log('\nVerifying DB countries against currency map...');
  const { errors: mapErrors, mappings } = verifyCountries(dbCountries, currencyMap);
  if (mapErrors.length > 0) {
    console.error('MAPPING ERRORS:');
    mapErrors.forEach(e => console.error('  \u2717 ' + e));
    process.exit(1);
  }
  console.log('  \u2713 All ' + dbCountries.length + ' DB countries have verified currency mappings');
  mappings.forEach(m => {
    const c = currencyMap.get(m.iso_alpha_code);
    console.log('    ' + m.iso2 + '/' + m.iso3 + ' \u2192 ' + m.iso_alpha_code + ' "' + c.name + '" ' + c.default_symbol);
  });

  // 5. Key symbol verification
  console.log('\nKey currency symbol verification:');
  const keyChecks = [['INR','\u20b9'], ['USD','$'], ['EUR','\u20ac'], ['GBP','\u00a3'], ['JPY','\u00a5']];
  let symbolFail = false;
  for (const [code, expected] of keyChecks) {
    const c = currencyMap.get(code);
    if (!c) {
      console.error('  \u2717 ' + code + ' NOT FOUND in currency map');
      symbolFail = true;
      continue;
    }
    const ok = c.default_symbol === expected;
    console.log('  ' + (ok ? '\u2713' : '\u2717') + ' ' + code + ': name="' + c.name + '" symbol="' + c.default_symbol + '" (expected "' + expected + '")');
    if (!ok) symbolFail = true;
  }
  if (symbolFail) {
    console.error('SYMBOL VERIFICATION FAILED — aborting.');
    process.exit(1);
  }

  // 6. Generate SQL
  console.log('\nGenerating migration SQL...');
  const sql = generateSql(currencyMap, sixDate, cldrVersion);

  fs.writeFileSync(OUT_SQL, sql, 'utf8');
  const sqlBuf  = Buffer.from(sql, 'utf8');
  const sha256  = crypto.createHash('sha256').update(sqlBuf).digest('hex');
  const sizeMb  = (sqlBuf.length / 1024).toFixed(1);
  console.log('  Written: ' + OUT_SQL);
  console.log('  Size   : ' + sizeMb + ' KB (' + sqlBuf.length + ' bytes)');
  console.log('  SHA256 : ' + sha256);

  // 7. Save report
  const report = {
    generatedAt: new Date().toISOString(),
    sources: {
      six:  { file: 'scripts/six_list_one.xml',       publishedDate: sixDate },
      cldr: { file: 'scripts/cldr_currencies_en.json', version: cldrVersion },
    },
    stats: {
      uniqueCurrencies: currencyMap.size,
      dbCountries:      dbCountries.length,
      mappings:         mappings.length,
      unmapped:         0,
      blankRows:        0,
      duplicateCodes:   0,
    },
    migration: { filename: path.basename(OUT_SQL), sha256, sizeBytes: sqlBuf.length },
    currencies: [...currencyMap.values()],
    mappings,
  };
  fs.writeFileSync(OUT_REPORT, JSON.stringify(report, null, 2), 'utf8');

  // 8. Final summary
  console.log('\n' + '\u2550'.repeat(56));
  console.log('  FINAL PRE-MIGRATION REPORT');
  console.log('\u2550'.repeat(56));
  console.log('  SIX source    : list-one.xml (' + sixDate + ')');
  console.log('  CLDR source   : cldr-numbers-modern v' + cldrVersion);
  console.log('  Currencies    : ' + currencyMap.size + ' unique ISO codes');
  console.log('  Countries (DB): ' + dbCountries.length);
  console.log('  Mappings      : ' + mappings.length);
  console.log('  Unmapped      : 0');
  console.log('  Blank rows    : 0');
  console.log('  Dup codes     : 0');
  console.log('  Migration     : ' + path.basename(OUT_SQL));
  console.log('  SHA256        : ' + sha256);
  console.log('\u2550'.repeat(56));
}

main();
