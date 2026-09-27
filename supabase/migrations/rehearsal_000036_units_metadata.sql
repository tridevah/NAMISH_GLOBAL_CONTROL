BEGIN;

-- ============================================================
-- rehearsal_000036_units_metadata.sql
-- STATUS: UNAPPLIED — review before executing against production
-- ============================================================

-- ── 1. ADD BUSINESS METADATA COLUMNS ────────────────────────────────────────

ALTER TABLE catalog.measurement_units
    ADD COLUMN IF NOT EXISTS business_name TEXT,
    ADD COLUMN IF NOT EXISTS short_name    TEXT,
    ADD COLUMN IF NOT EXISTS is_business   BOOLEAN DEFAULT false;


-- ── 1a. ENFORCE BUSINESS UNIT UNIQUENESS ─────────────────────────────────────
CREATE UNIQUE INDEX IF NOT EXISTS uq_business_unit_identity
    ON catalog.measurement_units (LOWER(TRIM(business_name)), LOWER(TRIM(short_name)))
    WHERE is_business = true;

-- ── 2. SEED MISSING NAMISH-OWNED PACKAGING ENTRIES ──────────────────────────
-- Only inserts if the canonical_code does not yet exist.
-- Preserves any existing UUID, created_at and references.

INSERT INTO catalog.measurement_units
    (canonical_code, standard_code, name, category, status, source, source_version, aliases)
VALUES
    ('NAMISH_BG', 'BG', 'bag',    'Packaging', 'ACTIVE', 'NAMISH_INTERNAL', '1.0', '{}'),
    ('NAMISH_BO', 'BO', 'bottle', 'Packaging', 'ACTIVE', 'NAMISH_INTERNAL', '1.0', '{}'),
    ('NAMISH_BX', 'BX', 'box',    'Packaging', 'ACTIVE', 'NAMISH_INTERNAL', '1.0', '{}'),
    ('NAMISH_BE', 'BD', 'bundle', 'Packaging', 'ACTIVE', 'NAMISH_INTERNAL', '1.0', '{}'),
    ('NAMISH_CA', 'CA', 'can',    'Packaging', 'ACTIVE', 'NAMISH_INTERNAL', '1.0', '{}'),
    ('NAMISH_CT', 'CT', 'carton', 'Packaging', 'ACTIVE', 'NAMISH_INTERNAL', '1.0', '{}'),
    ('NAMISH_PK', 'PK', 'pack',   'Packaging', 'ACTIVE', 'NAMISH_INTERNAL', '1.0', '{}'),
    ('NAMISH_RO', 'RO', 'roll',   'Packaging', 'ACTIVE', 'NAMISH_INTERNAL', '1.0', '{}')
ON CONFLICT (canonical_code) DO NOTHING;

-- ── 3. VALIDATE PACKAGING DEFINITIONS BEFORE UPDATING METADATA ──────────────
-- Scoped to the eight NAMISH entries only.
-- Uses IS NOT DISTINCT FROM for null-safe comparison.
-- Aborts the transaction on any mismatch.

DO $$
DECLARE
    v_row catalog.measurement_units%ROWTYPE;
    v_checks RECORD;
BEGIN
    FOR v_checks IN
        SELECT
            canonical_code_expected,
            standard_code_expected,
            name_expected,
            category_expected,
            source_expected,
            source_version_expected
        FROM (VALUES
            ('NAMISH_BG', 'BG', 'bag',    'Packaging', 'NAMISH_INTERNAL', '1.0'),
            ('NAMISH_BO', 'BO', 'bottle', 'Packaging', 'NAMISH_INTERNAL', '1.0'),
            ('NAMISH_BX', 'BX', 'box',    'Packaging', 'NAMISH_INTERNAL', '1.0'),
            ('NAMISH_BE', 'BD', 'bundle', 'Packaging', 'NAMISH_INTERNAL', '1.0'),
            ('NAMISH_CA', 'CA', 'can',    'Packaging', 'NAMISH_INTERNAL', '1.0'),
            ('NAMISH_CT', 'CT', 'carton', 'Packaging', 'NAMISH_INTERNAL', '1.0'),
            ('NAMISH_PK', 'PK', 'pack',   'Packaging', 'NAMISH_INTERNAL', '1.0'),
            ('NAMISH_RO', 'RO', 'roll',   'Packaging', 'NAMISH_INTERNAL', '1.0')
        ) AS t(canonical_code_expected, standard_code_expected, name_expected,
               category_expected, source_expected, source_version_expected)
    LOOP
        SELECT * INTO v_row
        FROM catalog.measurement_units
        WHERE canonical_code = v_checks.canonical_code_expected;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Packaging conflict: % not found after insert', v_checks.canonical_code_expected;
        END IF;

        IF v_row.standard_code IS DISTINCT FROM v_checks.standard_code_expected THEN
            RAISE EXCEPTION 'Packaging conflict: % standard_code is "%" expected "%"',
                v_checks.canonical_code_expected, v_row.standard_code, v_checks.standard_code_expected;
        END IF;

        IF v_row.name IS DISTINCT FROM v_checks.name_expected THEN
            RAISE EXCEPTION 'Packaging conflict: % name is "%" expected "%"',
                v_checks.canonical_code_expected, v_row.name, v_checks.name_expected;
        END IF;

        IF v_row.category IS DISTINCT FROM v_checks.category_expected THEN
            RAISE EXCEPTION 'Packaging conflict: % category is "%" expected "%"',
                v_checks.canonical_code_expected, v_row.category, v_checks.category_expected;
        END IF;

        IF v_row.source IS DISTINCT FROM v_checks.source_expected THEN
            RAISE EXCEPTION 'Packaging conflict: % source is "%" expected "%"',
                v_checks.canonical_code_expected, v_row.source, v_checks.source_expected;
        END IF;

        IF v_row.source_version IS DISTINCT FROM v_checks.source_version_expected THEN
            RAISE EXCEPTION 'Packaging conflict: % source_version is "%" expected "%"',
                v_checks.canonical_code_expected, v_row.source_version, v_checks.source_version_expected;
        END IF;
    END LOOP;
END $$;

-- ── 4. APPLY BUSINESS METADATA ───────────────────────────────────────────────
-- Each statement is scoped by exact canonical_code. Canonical/source fields
-- are intentionally not touched. KGS alias merged non-destructively.

UPDATE catalog.measurement_units SET business_name = 'BAGS',             short_name = 'Bag',  is_business = true WHERE canonical_code = 'NAMISH_BG';
UPDATE catalog.measurement_units SET business_name = 'BOTTLES',          short_name = 'Btl',  is_business = true WHERE canonical_code = 'NAMISH_BO';
UPDATE catalog.measurement_units SET business_name = 'BOX',              short_name = 'Box',  is_business = true WHERE canonical_code = 'NAMISH_BX';
UPDATE catalog.measurement_units SET business_name = 'BUNDLES',          short_name = 'Bdl',  is_business = true WHERE canonical_code = 'NAMISH_BE';
UPDATE catalog.measurement_units SET business_name = 'CANS',             short_name = 'Can',  is_business = true WHERE canonical_code = 'NAMISH_CA';
UPDATE catalog.measurement_units SET business_name = 'CARTONS',          short_name = 'Ctn',  is_business = true WHERE canonical_code = 'NAMISH_CT';
UPDATE catalog.measurement_units SET business_name = 'CUBIC METER',      short_name = 'Cbm',  is_business = true WHERE canonical_code = 'UNECE_REC20_MTQ';
UPDATE catalog.measurement_units SET business_name = 'DAY',              short_name = 'Day',  is_business = true WHERE canonical_code = 'UNECE_REC20_DAY';
UPDATE catalog.measurement_units SET business_name = 'DOZENS',           short_name = 'Dzn',  is_business = true WHERE canonical_code = 'UNECE_REC20_DZN';
UPDATE catalog.measurement_units SET business_name = 'GRAMMES',          short_name = 'Gm',   is_business = true WHERE canonical_code = 'UNECE_REC20_GRM';
UPDATE catalog.measurement_units SET business_name = 'MILLIGRAM',        short_name = 'mg',   is_business = true WHERE canonical_code = 'UNECE_REC20_MGM';
UPDATE catalog.measurement_units SET business_name = 'HOUR',             short_name = 'Hr',   is_business = true WHERE canonical_code = 'UNECE_REC20_HUR';
UPDATE catalog.measurement_units
    SET business_name = 'KILOGRAMS',  short_name = 'Kg',  is_business = true,
        aliases = ARRAY(SELECT DISTINCT unnest(array_cat(COALESCE(aliases, '{}'), ARRAY['KGS'])))
    WHERE canonical_code = 'UNECE_REC20_KGM';
UPDATE catalog.measurement_units SET business_name = 'KILOMETER',        short_name = 'Km',   is_business = true WHERE canonical_code = 'UNECE_REC20_KMT';
UPDATE catalog.measurement_units SET business_name = 'LITRE',            short_name = 'Ltr',  is_business = true WHERE canonical_code = 'UNECE_REC20_LTR';
UPDATE catalog.measurement_units SET business_name = 'METERS',           short_name = 'Mtr',  is_business = true WHERE canonical_code = 'UNECE_REC20_MTR';
UPDATE catalog.measurement_units SET business_name = 'MILLILITRE',       short_name = 'Ml',   is_business = true WHERE canonical_code = 'UNECE_REC20_MLT';
UPDATE catalog.measurement_units SET business_name = 'NUMBERS',          short_name = 'Nos',  is_business = true WHERE canonical_code = 'UNECE_REC20_C62';
UPDATE catalog.measurement_units SET business_name = 'PACKS',            short_name = 'Pac',  is_business = true WHERE canonical_code = 'NAMISH_PK';
UPDATE catalog.measurement_units SET business_name = 'PAIRS',            short_name = 'Prs',  is_business = true WHERE canonical_code = 'UNECE_REC20_PR';
UPDATE catalog.measurement_units SET business_name = 'PIECES',           short_name = 'Pcs',  is_business = true WHERE canonical_code = 'UNECE_REC20_H87';
UPDATE catalog.measurement_units SET business_name = 'QUINTAL',          short_name = 'Qtl',  is_business = true WHERE canonical_code = 'UNECE_REC20_DTN';
UPDATE catalog.measurement_units SET business_name = 'ROLLS',            short_name = 'Rol',  is_business = true WHERE canonical_code = 'NAMISH_RO';
UPDATE catalog.measurement_units SET business_name = 'SERVICE',          short_name = 'Ser',  is_business = true WHERE canonical_code = 'UNECE_REC20_E48';
UPDATE catalog.measurement_units SET business_name = 'SET',              short_name = 'Set',  is_business = true WHERE canonical_code = 'UNECE_REC20_SET';
UPDATE catalog.measurement_units SET business_name = 'SQUARE FEET',      short_name = 'Sqf',  is_business = true WHERE canonical_code = 'UNECE_REC20_FTK';
UPDATE catalog.measurement_units SET business_name = 'SQUARE METERS',    short_name = 'Sqm',  is_business = true WHERE canonical_code = 'UNECE_REC20_MTK';
UPDATE catalog.measurement_units SET business_name = 'TABLETS',          short_name = 'Tbs',  is_business = true WHERE canonical_code = 'UNECE_REC20_U2';
UPDATE catalog.measurement_units SET business_name = 'TON / METRIC TON', short_name = 'Ton',  is_business = true WHERE canonical_code = 'UNECE_REC20_TNE';
UPDATE catalog.measurement_units SET business_name = 'UNIT',             short_name = 'Unit', is_business = true WHERE canonical_code = 'UNECE_REC20_EA';

-- ── 5. RECREATE PUBLIC VIEW ───────────────────────────────────────────────────
-- CREATE OR REPLACE preserves dependent objects. No CASCADE drop.

CREATE OR REPLACE VIEW public.measurement_units AS
    SELECT * FROM catalog.measurement_units;


-- ── 5a. COMPUTED FIELD FOR ALIAS SEARCH ──────────────────────────────────────
CREATE OR REPLACE FUNCTION public.aliases_text(u public.measurement_units)
RETURNS TEXT
LANGUAGE sql IMMUTABLE
AS $func$
  SELECT array_to_string(u.aliases, ' ');
$func$;

-- ── 6. RESTORE PERMISSIONS (unchanged from schema migration 20260918000001) ──
-- The public view is SELECT-only for service_role.
-- No INSERT/UPDATE/DELETE granted on the public view to anyone.
-- All writes go through SECURITY DEFINER RPCs in the catalog schema.

REVOKE ALL ON public.measurement_units FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON public.measurement_units TO service_role;

-- ── 7. MUTATION RPCS ─────────────────────────────────────────────────────────
-- Both functions are SECURITY DEFINER, scoped to catalog schema.
-- Revoked from all non-service-role principals.
-- canonical_code is always server-generated (never client-supplied).
-- PATCH preserves omitted fields via COALESCE.
-- PATCH raises P0002 on NOT FOUND so the handler can map it to 404.
-- Source/canonical fields are intentionally excluded from PATCH parameters.

CREATE OR REPLACE FUNCTION catalog.add_business_unit_impl(
    p_business_name TEXT,
    p_short_name    TEXT,
    p_aliases       TEXT[]
) RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = catalog, public, pg_temp
AS $$
DECLARE
    v_canonical_code TEXT;
    v_res            JSON;
BEGIN
    -- Generate immutable NAMISH-owned canonical identity
    v_canonical_code := 'NAMISH_' || UPPER(REGEXP_REPLACE(p_short_name, '[^A-Za-z0-9]', '_', 'g'));

    IF EXISTS (SELECT 1 FROM catalog.measurement_units WHERE canonical_code = v_canonical_code) THEN
        RAISE EXCEPTION 'Business unit with canonical code % already exists', v_canonical_code
            USING ERRCODE = '23505';
    END IF;

    INSERT INTO catalog.measurement_units (
        canonical_code, standard_code, name,
        category, status, source, source_version,
        business_name, short_name, is_business, aliases
    )
    VALUES (
        v_canonical_code,
        SUBSTRING(UPPER(p_short_name) FROM 1 FOR 3),
        LOWER(p_business_name),
        'Business', 'ACTIVE', 'NAMISH_INTERNAL', '1.0',
        p_business_name, p_short_name, true,
        COALESCE(p_aliases, '{}')
    )
    RETURNING row_to_json(measurement_units.*) INTO v_res;

    RETURN v_res;
END;
$$;

CREATE OR REPLACE FUNCTION catalog.update_business_unit_impl(
    p_id            UUID,
    p_business_name TEXT,
    p_short_name    TEXT,
    p_aliases       TEXT[],
    p_status        TEXT,
    p_is_business   BOOLEAN
) RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = catalog, public, pg_temp
AS $$
DECLARE
    v_res JSON;
BEGIN
    UPDATE catalog.measurement_units
    SET
        business_name = COALESCE(p_business_name, business_name),
        short_name    = COALESCE(p_short_name,    short_name),
        aliases       = COALESCE(p_aliases,        aliases),
        status        = COALESCE(p_status,         status),
        is_business   = COALESCE(p_is_business,    is_business),
        updated_at    = NOW()
        -- canonical_code, standard_code, name, source, source_version intentionally excluded
    WHERE id = p_id
    RETURNING row_to_json(measurement_units.*) INTO v_res;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Business unit not found'
            USING ERRCODE = 'P0002';
    END IF;

    RETURN v_res;
END;
$$;

-- Public wrappers (reachable by service_role via PostgREST RPC)
CREATE OR REPLACE FUNCTION public.rpc_add_business_unit(
    p_business_name TEXT,
    p_short_name    TEXT,
    p_aliases       TEXT[]
) RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    RETURN catalog.add_business_unit_impl(p_business_name, p_short_name, p_aliases);
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_update_business_unit(
    p_id            UUID,
    p_business_name TEXT,
    p_short_name    TEXT,
    p_aliases       TEXT[],
    p_status        TEXT,
    p_is_business   BOOLEAN
) RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    RETURN catalog.update_business_unit_impl(p_id, p_business_name, p_short_name, p_aliases, p_status, p_is_business);
END;
$$;

REVOKE ALL ON FUNCTION catalog.add_business_unit_impl(TEXT, TEXT, TEXT[])
    FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION catalog.update_business_unit_impl(UUID, TEXT, TEXT, TEXT[], TEXT, BOOLEAN)
    FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.rpc_add_business_unit(TEXT, TEXT, TEXT[])
    FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.rpc_update_business_unit(UUID, TEXT, TEXT, TEXT[], TEXT, BOOLEAN)
    FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.rpc_add_business_unit(TEXT, TEXT, TEXT[])
    TO service_role;

GRANT EXECUTE ON FUNCTION public.rpc_update_business_unit(UUID, TEXT, TEXT, TEXT[], TEXT, BOOLEAN)
    TO service_role;

-- ── 8. ASSERTIONS ────────────────────────────────────────────────────────────
-- Validates each of the 30 expected records individually.
-- Does NOT assert total count = 30 (additional units are allowed).
-- Validates all 8 NAMISH packaging identities for business_name/short_name.
-- Validates permission state.

DO $$
DECLARE
    v_checks RECORD;
BEGIN
    -- 8a. Validate all 30 expected canonical codes have is_business = true
    FOR v_checks IN
        SELECT canonical_code_expected, business_name_expected, short_name_expected
        FROM (VALUES
            ('NAMISH_BG',        'BAGS',             'Bag'),
            ('NAMISH_BO',        'BOTTLES',           'Btl'),
            ('NAMISH_BX',        'BOX',               'Box'),
            ('NAMISH_BE',        'BUNDLES',           'Bdl'),
            ('NAMISH_CA',        'CANS',              'Can'),
            ('NAMISH_CT',        'CARTONS',           'Ctn'),
            ('UNECE_REC20_MTQ',  'CUBIC METER',       'Cbm'),
            ('UNECE_REC20_DAY',  'DAY',               'Day'),
            ('UNECE_REC20_DZN',  'DOZENS',            'Dzn'),
            ('UNECE_REC20_GRM',  'GRAMMES',           'Gm'),
            ('UNECE_REC20_MGM',  'MILLIGRAM',         'mg'),
            ('UNECE_REC20_HUR',  'HOUR',              'Hr'),
            ('UNECE_REC20_KGM',  'KILOGRAMS',         'Kg'),
            ('UNECE_REC20_KMT',  'KILOMETER',         'Km'),
            ('UNECE_REC20_LTR',  'LITRE',             'Ltr'),
            ('UNECE_REC20_MTR',  'METERS',            'Mtr'),
            ('UNECE_REC20_MLT',  'MILLILITRE',        'Ml'),
            ('UNECE_REC20_C62',  'NUMBERS',           'Nos'),
            ('NAMISH_PK',        'PACKS',             'Pac'),
            ('UNECE_REC20_PR',   'PAIRS',             'Prs'),
            ('UNECE_REC20_H87',  'PIECES',            'Pcs'),
            ('UNECE_REC20_DTN',  'QUINTAL',           'Qtl'),
            ('NAMISH_RO',        'ROLLS',             'Rol'),
            ('UNECE_REC20_E48',  'SERVICE',           'Ser'),
            ('UNECE_REC20_SET',  'SET',               'Set'),
            ('UNECE_REC20_FTK',  'SQUARE FEET',       'Sqf'),
            ('UNECE_REC20_MTK',  'SQUARE METERS',     'Sqm'),
            ('UNECE_REC20_U2',   'TABLETS',           'Tbs'),
            ('UNECE_REC20_TNE',  'TON / METRIC TON',  'Ton'),
            ('UNECE_REC20_EA',   'UNIT',              'Unit')
        ) AS t(canonical_code_expected, business_name_expected, short_name_expected)
    LOOP
        IF NOT EXISTS (
            SELECT 1 FROM catalog.measurement_units
            WHERE canonical_code = v_checks.canonical_code_expected
              AND business_name  IS NOT DISTINCT FROM v_checks.business_name_expected
              AND short_name     IS NOT DISTINCT FROM v_checks.short_name_expected
              AND is_business    = true
        ) THEN
            RAISE EXCEPTION
                'Assertion failed: % — expected business_name="%", short_name="%", is_business=true',
                v_checks.canonical_code_expected,
                v_checks.business_name_expected,
                v_checks.short_name_expected;
        END IF;
    END LOOP;

    -- 8b. Validate KGS alias is present on KILOGRAMS
    IF NOT EXISTS (
        SELECT 1 FROM catalog.measurement_units
        WHERE canonical_code = 'UNECE_REC20_KGM'
          AND 'KGS' = ANY(aliases)
    ) THEN
        RAISE EXCEPTION 'Assertion failed: UNECE_REC20_KGM is missing KGS alias';
    END IF;

    -- 8c. Validate NAMISH packaging source integrity
    IF EXISTS (
        SELECT 1 FROM catalog.measurement_units
        WHERE canonical_code LIKE 'NAMISH_%'
          AND source IS DISTINCT FROM 'NAMISH_INTERNAL'
    ) THEN
        RAISE EXCEPTION 'Assertion failed: NAMISH packaging identity conflict — unexpected source value';
    END IF;

    -- 8d. Validate view permissions (mirror of schema migration assertion)
    IF has_table_privilege('anon',          'public.measurement_units', 'SELECT') OR
       has_table_privilege('authenticated', 'public.measurement_units', 'SELECT')
    THEN
        RAISE EXCEPTION 'Assertion failed: public.measurement_units incorrectly exposed to anon/authenticated';
    END IF;

    IF NOT has_table_privilege('service_role', 'public.measurement_units', 'SELECT') THEN
        RAISE EXCEPTION 'Assertion failed: service_role lacks SELECT on public.measurement_units';
    END IF;

    IF has_table_privilege('service_role', 'public.measurement_units', 'INSERT') OR
       has_table_privilege('service_role', 'public.measurement_units', 'UPDATE') OR
       has_table_privilege('service_role', 'public.measurement_units', 'DELETE')
    THEN
        RAISE EXCEPTION 'Assertion failed: service_role incorrectly granted write access on public.measurement_units';
    END IF;
END $$;

NOTIFY pgrst, 'reload schema';

COMMIT;
