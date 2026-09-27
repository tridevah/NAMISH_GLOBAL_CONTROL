-- =============================================================
-- Migration: 20260901000004_currency_master_canonical.sql
-- Purpose  : Canonical ISO 4217 currency master load + public RPCs
-- Authority: SIX ISO 4217 List One (2026-01-01)
--            Unicode CLDR v45.0.0 (currency symbols, en locale)
-- Scope    : catalog.currencies insert/upsert only.
--            Does NOT modify geography, village/locality, or R16 data.
-- Isolation: SERIALIZABLE + advisory lock
-- =============================================================

BEGIN ISOLATION LEVEL SERIALIZABLE;
SET LOCAL search_path TO catalog, public, pg_catalog;
SET LOCAL statement_timeout = '3min';
SET LOCAL lock_timeout = '15s';
SET LOCAL idle_in_transaction_session_timeout = '3min';
SET CONSTRAINTS ALL IMMEDIATE;

-- Advisory lock: prevent concurrent currency master writes
DO $$
DECLARE v_lock boolean;
BEGIN
  SELECT pg_try_advisory_xact_lock(hashtext('CURRENCY_MASTER_CANONICAL')) INTO v_lock;
  IF NOT v_lock THEN
    RAISE EXCEPTION 'Could not obtain advisory lock CURRENCY_MASTER_CANONICAL.';
  END IF;
END $$;

-- ── Section 0: Safe Schema Evolution ────────────────────────────────────────
-- The remote DB might be missing migration 20260827000006_tax_currency_scopes.
-- Safely evolve the schema to ensure columns exist before inserting.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='catalog' AND table_name='currencies' AND column_name='code') THEN
    ALTER TABLE catalog.currencies RENAME COLUMN code TO iso_alpha_code;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='catalog' AND table_name='currencies' AND column_name='symbol') THEN
    ALTER TABLE catalog.currencies RENAME COLUMN symbol TO default_symbol;
  END IF;
END $$;

ALTER TABLE catalog.currencies
  ADD COLUMN IF NOT EXISTS iso_numeric_code TEXT,
  ADD COLUMN IF NOT EXISTS native_symbol TEXT,
  ADD COLUMN IF NOT EXISTS minor_units INT DEFAULT 2,
  ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'ACTIVE',
  ADD COLUMN IF NOT EXISTS effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS effective_to TIMESTAMPTZ;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'currencies_iso_alpha_code_key') THEN
    ALTER TABLE catalog.currencies ADD CONSTRAINT currencies_iso_alpha_code_key UNIQUE (iso_alpha_code);
  END IF;
END $$;

-- ── Section 1: Canonical currency upsert (164 unique ISO codes) ─────────────
INSERT INTO catalog.currencies
  (iso_alpha_code, name, default_symbol, native_symbol, iso_numeric_code, minor_units, status)
VALUES
  ('AED', 'United Arab Emirates Dirham', 'AED', 'AED', '784', 2, 'ACTIVE'),
  ('AFN', 'Afghan Afghani', '؋', '؋', '971', 2, 'ACTIVE'),
  ('ALL', 'Albanian Lek', 'ALL', 'ALL', '008', 2, 'ACTIVE'),
  ('AMD', 'Armenian Dram', '֏', '֏', '051', 2, 'ACTIVE'),
  ('AOA', 'Angolan Kwanza', 'Kz', 'Kz', '973', 2, 'ACTIVE'),
  ('ARS', 'Argentine Peso', '$', '$', '032', 2, 'ACTIVE'),
  ('AUD', 'Australian Dollar', 'A$', 'A$', '036', 2, 'ACTIVE'),
  ('AWG', 'Aruban Florin', 'AWG', 'AWG', '533', 2, 'ACTIVE'),
  ('AZN', 'Azerbaijani Manat', '₼', '₼', '944', 2, 'ACTIVE'),
  ('BAM', 'Bosnia-Herzegovina Convertible Mark', 'KM', 'KM', '977', 2, 'ACTIVE'),
  ('BBD', 'Barbadian Dollar', '$', '$', '052', 2, 'ACTIVE'),
  ('BDT', 'Bangladeshi Taka', '৳', '৳', '050', 2, 'ACTIVE'),
  ('BHD', 'Bahraini Dinar', 'BHD', 'BHD', '048', 3, 'ACTIVE'),
  ('BIF', 'Burundian Franc', 'BIF', 'BIF', '108', 0, 'ACTIVE'),
  ('BMD', 'Bermudan Dollar', '$', '$', '060', 2, 'ACTIVE'),
  ('BND', 'Brunei Dollar', '$', '$', '096', 2, 'ACTIVE'),
  ('BOB', 'Bolivian Boliviano', 'Bs', 'Bs', '068', 2, 'ACTIVE'),
  ('BOV', 'Bolivian Mvdol', 'BOV', 'BOV', '984', 2, 'ACTIVE'),
  ('BRL', 'Brazilian Real', 'R$', 'R$', '986', 2, 'ACTIVE'),
  ('BSD', 'Bahamian Dollar', '$', '$', '044', 2, 'ACTIVE'),
  ('BTN', 'Bhutanese Ngultrum', 'BTN', 'BTN', '064', 2, 'ACTIVE'),
  ('BWP', 'Botswanan Pula', 'P', 'P', '072', 2, 'ACTIVE'),
  ('BYN', 'Belarusian Ruble', 'BYN', 'BYN', '933', 2, 'ACTIVE'),
  ('BZD', 'Belize Dollar', '$', '$', '084', 2, 'ACTIVE'),
  ('CAD', 'Canadian Dollar', 'CA$', 'CA$', '124', 2, 'ACTIVE'),
  ('CDF', 'Congolese Franc', 'CDF', 'CDF', '976', 2, 'ACTIVE'),
  ('CHE', 'WIR Euro', 'CHE', 'CHE', '947', 2, 'ACTIVE'),
  ('CHF', 'Swiss Franc', 'CHF', 'CHF', '756', 2, 'ACTIVE'),
  ('CHW', 'WIR Franc', 'CHW', 'CHW', '948', 2, 'ACTIVE'),
  ('CLF', 'Chilean Unit of Account (UF)', 'CLF', 'CLF', '990', 4, 'ACTIVE'),
  ('CLP', 'Chilean Peso', '$', '$', '152', 0, 'ACTIVE'),
  ('CNY', 'Chinese Yuan', 'CN¥', 'CN¥', '156', 2, 'ACTIVE'),
  ('COP', 'Colombian Peso', '$', '$', '170', 2, 'ACTIVE'),
  ('COU', 'Colombian Real Value Unit', 'COU', 'COU', '970', 2, 'ACTIVE'),
  ('CRC', 'Costa Rican Colón', '₡', '₡', '188', 2, 'ACTIVE'),
  ('CUP', 'Cuban Peso', '$', '$', '192', 2, 'ACTIVE'),
  ('CVE', 'Cape Verdean Escudo', 'CVE', 'CVE', '132', 2, 'ACTIVE'),
  ('CZK', 'Czech Koruna', 'Kč', 'Kč', '203', 2, 'ACTIVE'),
  ('DJF', 'Djiboutian Franc', 'DJF', 'DJF', '262', 0, 'ACTIVE'),
  ('DKK', 'Danish Krone', 'kr', 'kr', '208', 2, 'ACTIVE'),
  ('DOP', 'Dominican Peso', '$', '$', '214', 2, 'ACTIVE'),
  ('DZD', 'Algerian Dinar', 'DZD', 'DZD', '012', 2, 'ACTIVE'),
  ('EGP', 'Egyptian Pound', 'E£', 'E£', '818', 2, 'ACTIVE'),
  ('ERN', 'Eritrean Nakfa', 'ERN', 'ERN', '232', 2, 'ACTIVE'),
  ('ETB', 'Ethiopian Birr', 'ETB', 'ETB', '230', 2, 'ACTIVE'),
  ('EUR', 'Euro', '€', '€', '978', 2, 'ACTIVE'),
  ('FJD', 'Fijian Dollar', '$', '$', '242', 2, 'ACTIVE'),
  ('FKP', 'Falkland Islands Pound', '£', '£', '238', 2, 'ACTIVE'),
  ('GBP', 'British Pound', '£', '£', '826', 2, 'ACTIVE'),
  ('GEL', 'Georgian Lari', '₾', '₾', '981', 2, 'ACTIVE'),
  ('GHS', 'Ghanaian Cedi', 'GH₵', 'GH₵', '936', 2, 'ACTIVE'),
  ('GIP', 'Gibraltar Pound', '£', '£', '292', 2, 'ACTIVE'),
  ('GMD', 'Gambian Dalasi', 'GMD', 'GMD', '270', 2, 'ACTIVE'),
  ('GNF', 'Guinean Franc', 'FG', 'FG', '324', 0, 'ACTIVE'),
  ('GTQ', 'Guatemalan Quetzal', 'Q', 'Q', '320', 2, 'ACTIVE'),
  ('GYD', 'Guyanaese Dollar', '$', '$', '328', 2, 'ACTIVE'),
  ('HKD', 'Hong Kong Dollar', 'HK$', 'HK$', '344', 2, 'ACTIVE'),
  ('HNL', 'Honduran Lempira', 'L', 'L', '340', 2, 'ACTIVE'),
  ('HTG', 'Haitian Gourde', 'HTG', 'HTG', '332', 2, 'ACTIVE'),
  ('HUF', 'Hungarian Forint', 'Ft', 'Ft', '348', 2, 'ACTIVE'),
  ('IDR', 'Indonesian Rupiah', 'Rp', 'Rp', '360', 2, 'ACTIVE'),
  ('ILS', 'Israeli New Shekel', '₪', '₪', '376', 2, 'ACTIVE'),
  ('INR', 'Indian Rupee', '₹', '₹', '356', 2, 'ACTIVE'),
  ('IQD', 'Iraqi Dinar', 'IQD', 'IQD', '368', 3, 'ACTIVE'),
  ('IRR', 'Iranian Rial', 'IRR', 'IRR', '364', 2, 'ACTIVE'),
  ('ISK', 'Icelandic Króna', 'kr', 'kr', '352', 0, 'ACTIVE'),
  ('JMD', 'Jamaican Dollar', '$', '$', '388', 2, 'ACTIVE'),
  ('JOD', 'Jordanian Dinar', 'JOD', 'JOD', '400', 3, 'ACTIVE'),
  ('JPY', 'Japanese Yen', '¥', '¥', '392', 0, 'ACTIVE'),
  ('KES', 'Kenyan Shilling', 'KES', 'KES', '404', 2, 'ACTIVE'),
  ('KGS', 'Kyrgystani Som', '⃀', '⃀', '417', 2, 'ACTIVE'),
  ('KHR', 'Cambodian Riel', '៛', '៛', '116', 2, 'ACTIVE'),
  ('KMF', 'Comorian Franc', 'CF', 'CF', '174', 0, 'ACTIVE'),
  ('KPW', 'North Korean Won', '₩', '₩', '408', 2, 'ACTIVE'),
  ('KRW', 'South Korean Won', '₩', '₩', '410', 0, 'ACTIVE'),
  ('KWD', 'Kuwaiti Dinar', 'KWD', 'KWD', '414', 3, 'ACTIVE'),
  ('KYD', 'Cayman Islands Dollar', '$', '$', '136', 2, 'ACTIVE'),
  ('KZT', 'Kazakhstani Tenge', '₸', '₸', '398', 2, 'ACTIVE'),
  ('LAK', 'Laotian Kip', '₭', '₭', '418', 2, 'ACTIVE'),
  ('LBP', 'Lebanese Pound', 'L£', 'L£', '422', 2, 'ACTIVE'),
  ('LKR', 'Sri Lankan Rupee', 'Rs', 'Rs', '144', 2, 'ACTIVE'),
  ('LRD', 'Liberian Dollar', '$', '$', '430', 2, 'ACTIVE'),
  ('LSL', 'Lesotho Loti', 'LSL', 'LSL', '426', 2, 'ACTIVE'),
  ('LYD', 'Libyan Dinar', 'LYD', 'LYD', '434', 3, 'ACTIVE'),
  ('MAD', 'Moroccan Dirham', 'MAD', 'MAD', '504', 2, 'ACTIVE'),
  ('MDL', 'Moldovan Leu', 'MDL', 'MDL', '498', 2, 'ACTIVE'),
  ('MGA', 'Malagasy Ariary', 'Ar', 'Ar', '969', 2, 'ACTIVE'),
  ('MKD', 'Macedonian Denar', 'MKD', 'MKD', '807', 2, 'ACTIVE'),
  ('MMK', 'Myanmar Kyat', 'K', 'K', '104', 2, 'ACTIVE'),
  ('MNT', 'Mongolian Tugrik', '₮', '₮', '496', 2, 'ACTIVE'),
  ('MOP', 'Macanese Pataca', 'MOP', 'MOP', '446', 2, 'ACTIVE'),
  ('MRU', 'Mauritanian Ouguiya', 'MRU', 'MRU', '929', 2, 'ACTIVE'),
  ('MUR', 'Mauritian Rupee', 'Rs', 'Rs', '480', 2, 'ACTIVE'),
  ('MVR', 'Maldivian Rufiyaa', 'MVR', 'MVR', '462', 2, 'ACTIVE'),
  ('MWK', 'Malawian Kwacha', 'MWK', 'MWK', '454', 2, 'ACTIVE'),
  ('MXN', 'Mexican Peso', 'MX$', 'MX$', '484', 2, 'ACTIVE'),
  ('MXV', 'Mexican Investment Unit', 'MXV', 'MXV', '979', 2, 'ACTIVE'),
  ('MYR', 'Malaysian Ringgit', 'RM', 'RM', '458', 2, 'ACTIVE'),
  ('MZN', 'Mozambican Metical', 'MZN', 'MZN', '943', 2, 'ACTIVE'),
  ('NAD', 'Namibian Dollar', '$', '$', '516', 2, 'ACTIVE'),
  ('NGN', 'Nigerian Naira', '₦', '₦', '566', 2, 'ACTIVE'),
  ('NIO', 'Nicaraguan Córdoba', 'C$', 'C$', '558', 2, 'ACTIVE'),
  ('NOK', 'Norwegian Krone', 'kr', 'kr', '578', 2, 'ACTIVE'),
  ('NPR', 'Nepalese Rupee', 'Rs', 'Rs', '524', 2, 'ACTIVE'),
  ('NZD', 'New Zealand Dollar', 'NZ$', 'NZ$', '554', 2, 'ACTIVE'),
  ('OMR', 'Omani Rial', 'OMR', 'OMR', '512', 3, 'ACTIVE'),
  ('PAB', 'Panamanian Balboa', 'PAB', 'PAB', '590', 2, 'ACTIVE'),
  ('PEN', 'Peruvian Sol', 'PEN', 'PEN', '604', 2, 'ACTIVE'),
  ('PGK', 'Papua New Guinean Kina', 'PGK', 'PGK', '598', 2, 'ACTIVE'),
  ('PHP', 'Philippine Peso', '₱', '₱', '608', 2, 'ACTIVE'),
  ('PKR', 'Pakistani Rupee', 'Rs', 'Rs', '586', 2, 'ACTIVE'),
  ('PLN', 'Polish Zloty', 'zł', 'zł', '985', 2, 'ACTIVE'),
  ('PYG', 'Paraguayan Guarani', '₲', '₲', '600', 0, 'ACTIVE'),
  ('QAR', 'Qatari Riyal', 'QAR', 'QAR', '634', 2, 'ACTIVE'),
  ('RON', 'Romanian Leu', 'lei', 'lei', '946', 2, 'ACTIVE'),
  ('RSD', 'Serbian Dinar', 'RSD', 'RSD', '941', 2, 'ACTIVE'),
  ('RUB', 'Russian Ruble', '₽', '₽', '643', 2, 'ACTIVE'),
  ('RWF', 'Rwandan Franc', 'RF', 'RF', '646', 0, 'ACTIVE'),
  ('SAR', 'Saudi Riyal', 'SAR', 'SAR', '682', 2, 'ACTIVE'),
  ('SBD', 'Solomon Islands Dollar', '$', '$', '090', 2, 'ACTIVE'),
  ('SCR', 'Seychellois Rupee', 'SCR', 'SCR', '690', 2, 'ACTIVE'),
  ('SDG', 'Sudanese Pound', 'SDG', 'SDG', '938', 2, 'ACTIVE'),
  ('SEK', 'Swedish Krona', 'kr', 'kr', '752', 2, 'ACTIVE'),
  ('SGD', 'Singapore Dollar', '$', '$', '702', 2, 'ACTIVE'),
  ('SHP', 'St. Helena Pound', '£', '£', '654', 2, 'ACTIVE'),
  ('SLE', 'Sierra Leonean Leone', 'SLE', 'SLE', '925', 2, 'ACTIVE'),
  ('SOS', 'Somali Shilling', 'SOS', 'SOS', '706', 2, 'ACTIVE'),
  ('SRD', 'Surinamese Dollar', '$', '$', '968', 2, 'ACTIVE'),
  ('SSP', 'South Sudanese Pound', '£', '£', '728', 2, 'ACTIVE'),
  ('STN', 'São Tomé & Príncipe Dobra', 'Db', 'Db', '930', 2, 'ACTIVE'),
  ('SVC', 'Salvadoran Colón', 'SVC', 'SVC', '222', 2, 'ACTIVE'),
  ('SYP', 'Syrian Pound', '£', '£', '760', 2, 'ACTIVE'),
  ('SZL', 'Swazi Lilangeni', 'SZL', 'SZL', '748', 2, 'ACTIVE'),
  ('THB', 'Thai Baht', '฿', '฿', '764', 2, 'ACTIVE'),
  ('TJS', 'Tajikistani Somoni', 'TJS', 'TJS', '972', 2, 'ACTIVE'),
  ('TMT', 'Turkmenistani Manat', 'TMT', 'TMT', '934', 2, 'ACTIVE'),
  ('TND', 'Tunisian Dinar', 'TND', 'TND', '788', 3, 'ACTIVE'),
  ('TOP', 'Tongan Paʻanga', 'T$', 'T$', '776', 2, 'ACTIVE'),
  ('TRY', 'Turkish Lira', '₺', '₺', '949', 2, 'ACTIVE'),
  ('TTD', 'Trinidad & Tobago Dollar', '$', '$', '780', 2, 'ACTIVE'),
  ('TWD', 'New Taiwan Dollar', 'NT$', 'NT$', '901', 2, 'ACTIVE'),
  ('TZS', 'Tanzanian Shilling', 'TZS', 'TZS', '834', 2, 'ACTIVE'),
  ('UAH', 'Ukrainian Hryvnia', '₴', '₴', '980', 2, 'ACTIVE'),
  ('UGX', 'Ugandan Shilling', 'UGX', 'UGX', '800', 0, 'ACTIVE'),
  ('USD', 'US Dollar', '$', '$', '840', 2, 'ACTIVE'),
  ('USN', 'US Dollar (Next day)', 'USN', 'USN', '997', 2, 'ACTIVE'),
  ('UYI', 'Uruguayan Peso (Indexed Units)', 'UYI', 'UYI', '940', 0, 'ACTIVE'),
  ('UYU', 'Uruguayan Peso', '$', '$', '858', 2, 'ACTIVE'),
  ('UYW', 'Uruguayan Nominal Wage Index Unit', 'UYW', 'UYW', '927', 4, 'ACTIVE'),
  ('UZS', 'Uzbekistani Som', 'UZS', 'UZS', '860', 2, 'ACTIVE'),
  ('VED', 'Bolívar Soberano', 'VED', 'VED', '926', 2, 'ACTIVE'),
  ('VES', 'Venezuelan Bolívar', 'VES', 'VES', '928', 2, 'ACTIVE'),
  ('VND', 'Vietnamese Dong', '₫', '₫', '704', 0, 'ACTIVE'),
  ('VUV', 'Vanuatu Vatu', 'VUV', 'VUV', '548', 0, 'ACTIVE'),
  ('WST', 'Samoan Tala', 'WST', 'WST', '882', 2, 'ACTIVE'),
  ('XAF', 'Central African CFA Franc', 'FCFA', 'FCFA', '950', 0, 'ACTIVE'),
  ('XCD', 'East Caribbean Dollar', 'EC$', 'EC$', '951', 2, 'ACTIVE'),
  ('XCG', 'Caribbean guilder', 'Cg.', 'Cg.', '532', 2, 'ACTIVE'),
  ('XOF', 'West African CFA Franc', 'F CFA', 'F CFA', '952', 0, 'ACTIVE'),
  ('XPF', 'CFP Franc', 'CFPF', 'CFPF', '953', 0, 'ACTIVE'),
  ('YER', 'Yemeni Rial', 'YER', 'YER', '886', 2, 'ACTIVE'),
  ('ZAR', 'South African Rand', 'R', 'R', '710', 2, 'ACTIVE'),
  ('ZMW', 'Zambian Kwacha', 'ZK', 'ZK', '967', 2, 'ACTIVE'),
  ('ZWG', 'Zimbabwe Gold', 'ZWG', 'ZWG', '924', 2, 'ACTIVE')
ON CONFLICT (iso_alpha_code) DO UPDATE
  SET
    name              = EXCLUDED.name,
    default_symbol    = EXCLUDED.default_symbol,
    native_symbol     = EXCLUDED.native_symbol,
    iso_numeric_code  = EXCLUDED.iso_numeric_code,
    minor_units       = EXCLUDED.minor_units,
    status            = EXCLUDED.status
  WHERE
    catalog.currencies.name              IS DISTINCT FROM EXCLUDED.name     OR
    catalog.currencies.default_symbol    IS DISTINCT FROM EXCLUDED.default_symbol OR
    catalog.currencies.native_symbol     IS DISTINCT FROM EXCLUDED.native_symbol OR
    catalog.currencies.iso_numeric_code  IS DISTINCT FROM EXCLUDED.iso_numeric_code OR
    catalog.currencies.minor_units       IS DISTINCT FROM EXCLUDED.minor_units;

-- ── Section 2: Public gateway RPC — rpc_get_currencies ──────────────────────
CREATE OR REPLACE FUNCTION public.rpc_get_currencies()
RETURNS SETOF catalog.currencies AS $$
BEGIN
  RETURN QUERY SELECT * FROM catalog.currencies WHERE status = 'ACTIVE' ORDER BY iso_alpha_code;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO pg_catalog;

REVOKE ALL ON FUNCTION public.rpc_get_currencies() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_get_currencies() TO service_role;

-- ── Section 3: Country→Currency resolution RPC ──────────────────────────────
CREATE OR REPLACE FUNCTION public.rpc_get_country_currencies(
  p_iso2 pg_catalog.text DEFAULT NULL
)
RETURNS pg_catalog.jsonb AS $$
DECLARE
  v_result pg_catalog.jsonb;
BEGIN
  SELECT pg_catalog.jsonb_agg(
    pg_catalog.jsonb_build_object(
      'iso_alpha_code',   cu.iso_alpha_code,
      'iso_numeric_code', cu.iso_numeric_code,
      'name',             cu.name,
      'default_symbol',   cu.default_symbol,
      'native_symbol',    cu.native_symbol,
      'minor_units',      cu.minor_units,
      'status',           cu.status,
      'country_iso2',     co.iso2,
      'country_iso3',     co.iso3,
      'country_name',     co.display_name
    )
    ORDER BY co.iso2
  ) INTO v_result
  FROM catalog.countries co
  JOIN catalog.currencies cu ON cu.iso_alpha_code = co.default_currency_code
  WHERE cu.status = 'ACTIVE'
    AND (p_iso2 IS NULL OR pg_catalog.upper(co.iso2) = pg_catalog.upper(p_iso2));

  RETURN pg_catalog.coalesce(v_result, '[]'::pg_catalog.jsonb);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO pg_catalog;

REVOKE ALL ON FUNCTION public.rpc_get_country_currencies(pg_catalog.text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_get_country_currencies(pg_catalog.text) TO service_role;

-- ── Section 4: Extend catalog.rpc_mutate_tax_entity to whitelist 'currencies' ──
CREATE OR REPLACE FUNCTION catalog.rpc_mutate_tax_entity(
    p_table_name pg_catalog.text,
    p_action     pg_catalog.text,
    p_payload    pg_catalog.jsonb,
    p_actor_id   pg_catalog.uuid
) RETURNS pg_catalog.jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO pg_catalog
AS $$
DECLARE
    v_result pg_catalog.jsonb;
    v_id     pg_catalog.uuid;
    v_sql    pg_catalog.text;
    v_cols   pg_catalog.text;
    v_vals   pg_catalog.text;
    v_set    pg_catalog.text;
BEGIN
    IF p_table_name NOT IN (
        'tax_regimes', 'tax_components', 'tax_codes', 'tax_rates',
        'tax_rate_component_sets', 'tax_rate_component_lines',
        'hsn_sac', 'hsn_sac_tax_codes',
        'currencies'
    ) THEN
        RAISE EXCEPTION 'Invalid table: %', p_table_name;
    END IF;

    IF p_action = 'INSERT' THEN
        SELECT pg_catalog.string_agg(pg_catalog.quote_ident(key), ', '),
               pg_catalog.string_agg('''' || pg_catalog.replace(value#>>'{}', '''', '''''') || '''', ', ')
        INTO v_cols, v_vals
        FROM pg_catalog.jsonb_each(p_payload);
        v_sql := 'INSERT INTO catalog.' || pg_catalog.quote_ident(p_table_name)
                 || ' (' || v_cols || ') VALUES (' || v_vals || ') RETURNING to_jsonb(*)';
        EXECUTE v_sql INTO v_result;
        v_id := (v_result->>'id')::pg_catalog.uuid;
    ELSIF p_action = 'UPDATE' THEN
        v_id := (p_payload->>'id')::pg_catalog.uuid;
        SELECT pg_catalog.string_agg(
               pg_catalog.quote_ident(key) || ' = ''' || pg_catalog.replace(value#>>'{}', '''', '''''') || '''', ', ')
        INTO v_set
        FROM pg_catalog.jsonb_each(p_payload) WHERE key != 'id';
        v_sql := 'UPDATE catalog.' || pg_catalog.quote_ident(p_table_name)
                 || ' SET ' || v_set || ' WHERE id = ''' || v_id || ''' RETURNING to_jsonb(*)';
        EXECUTE v_sql INTO v_result;
    ELSE
        RAISE EXCEPTION 'Invalid action: %', p_action;
    END IF;

    INSERT INTO audit.logs (actor_id, action, resource, resource_id, metadata)
    VALUES (p_actor_id, 'TAX_MUTATION_' || p_action, 'catalog.' || p_table_name, v_id, p_payload);

    RETURN v_result;
END;
$$;
REVOKE ALL ON FUNCTION catalog.rpc_mutate_tax_entity(
    pg_catalog.text, pg_catalog.text, pg_catalog.jsonb, pg_catalog.uuid
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION catalog.rpc_mutate_tax_entity(
    pg_catalog.text, pg_catalog.text, pg_catalog.jsonb, pg_catalog.uuid
) TO service_role;

-- ── Section 5: In-migration verification ────────────────────────────────────
DO $$
DECLARE
  v_currency_count   int;
  v_blank_count      int;
  v_dup_count        int;
  v_unmapped_count   int;
  v_country_count    int;
  v_mapping_count    int;
  v_unmapped_detail  text;
BEGIN
  SELECT count(*) INTO v_currency_count FROM catalog.currencies WHERE status = 'ACTIVE';

  -- Blank name/code/symbol check
  SELECT count(*) INTO v_blank_count FROM catalog.currencies
  WHERE status = 'ACTIVE'
    AND (pg_catalog.btrim(COALESCE(name,'')) = ''
      OR pg_catalog.btrim(COALESCE(iso_alpha_code,'')) = ''
      OR pg_catalog.btrim(COALESCE(default_symbol,'')) = '');
  IF v_blank_count > 0 THEN
    RAISE EXCEPTION 'VERIFICATION FAILED: % currencies have blank name/code/symbol', v_blank_count;
  END IF;

  -- Duplicate ISO alpha code check
  SELECT count(*) INTO v_dup_count
  FROM (SELECT iso_alpha_code FROM catalog.currencies GROUP BY iso_alpha_code HAVING count(*) > 1) x;
  IF v_dup_count > 0 THEN
    RAISE EXCEPTION 'VERIFICATION FAILED: % duplicate ISO alpha codes', v_dup_count;
  END IF;

  -- Every DB country must have its default_currency_code present
  SELECT count(*) INTO v_country_count FROM catalog.countries;
  SELECT count(*) INTO v_unmapped_count FROM catalog.countries co
  WHERE NOT EXISTS (
    SELECT 1 FROM catalog.currencies cu WHERE cu.iso_alpha_code = co.default_currency_code
  );
  IF v_unmapped_count > 0 THEN
    SELECT pg_catalog.string_agg(iso2 || '(' || default_currency_code || ')', ', ')
    INTO v_unmapped_detail FROM catalog.countries co
    WHERE NOT EXISTS (SELECT 1 FROM catalog.currencies cu WHERE cu.iso_alpha_code = co.default_currency_code);
    RAISE EXCEPTION 'VERIFICATION FAILED: % countries unmapped: %', v_unmapped_count, v_unmapped_detail;
  END IF;

  -- Mapping count
  SELECT count(*) INTO v_mapping_count FROM catalog.countries co
  JOIN catalog.currencies cu ON cu.iso_alpha_code = co.default_currency_code;

  RAISE NOTICE
    E'CURRENCY MASTER VERIFICATION PASSED\n'
    '  Unique currencies loaded : %\n'
    '  Countries in DB          : %\n'
    '  Country-currency mappings: %\n'
    '  Unmapped countries       : 0\n'
    '  Blank rows               : 0\n'
    '  Duplicate codes          : 0',
    v_currency_count, v_country_count, v_mapping_count;
END $$;

COMMIT;

-- End of migration 20260901000004_currency_master_canonical.sql