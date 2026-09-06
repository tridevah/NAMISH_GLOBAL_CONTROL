-- Migration 20260904000033: GST Rate Scope and Completeness
-- Adds: rate_code, usage_scope, erp_visibility, statutory_rate_percent,
--       effective_display_percent, valuation_basis, itc_policy, conditions
-- Inserts: 0.10% merchant-export and 7.5% real-estate rows (2 new rows → total 14)
-- Creates: catalog.gst_rate_applications
-- Updates: public.gst_rate_master view (drop+recreate) with new columns
-- No HSN/SAC, Geography, Currency, tenant or billing DML.
-- India country_tax_coverage remains UNRESOLVED.

-- ─── 1. ADD COLUMNS ───────────────────────────────────────────────────────────
ALTER TABLE catalog.gst_rate_master
    ADD COLUMN rate_code               TEXT,
    ADD COLUMN usage_scope             TEXT,
    ADD COLUMN erp_visibility          TEXT,
    ADD COLUMN statutory_rate_percent  NUMERIC,
    ADD COLUMN effective_display_percent NUMERIC,
    ADD COLUMN valuation_basis         TEXT,
    ADD COLUMN itc_policy              TEXT,
    ADD COLUMN conditions              JSONB;

-- ─── 2. POPULATE NEW COLUMNS FOR EXISTING 12 ROWS ────────────────────────────

-- 28% historical (is_current=false, was already INACTIVE)
UPDATE catalog.gst_rate_master SET
    rate_code                 = 'IN_GST_HIST_28',
    usage_scope               = 'HISTORICAL',
    erp_visibility            = 'HIDDEN',
    statutory_rate_percent    = 28.00,
    effective_display_percent = 28.00,
    valuation_basis           = 'TRANSACTION_VALUE',
    itc_policy                = 'DEFAULT',
    conditions                = '{"historical": true, "effective_to": "2026-01-31"}'::jsonb
WHERE id = '6f7c7d88-2332-4321-8427-9a5a2db9a3e1';

-- 0% NIL
UPDATE catalog.gst_rate_master SET
    rate_code                 = 'IN_GST_0',
    usage_scope               = 'TRANSACTION_RATE',
    erp_visibility            = 'GENERAL',
    statutory_rate_percent    = 0.00,
    effective_display_percent = 0.00,
    valuation_basis           = 'TRANSACTION_VALUE',
    itc_policy                = 'DEFAULT',
    conditions                = '{"treatment": "NIL_RATED"}'::jsonb
WHERE id = '623362ce-7aed-4e48-a429-a502eb5e2387';

-- 0.25% SPECIAL
UPDATE catalog.gst_rate_master SET
    rate_code                 = 'IN_GST_0_25',
    usage_scope               = 'TRANSACTION_RATE',
    erp_visibility            = 'GENERAL',
    statutory_rate_percent    = 0.25,
    effective_display_percent = 0.25,
    valuation_basis           = 'TRANSACTION_VALUE',
    itc_policy                = 'DEFAULT',
    conditions                = NULL
WHERE id = '6a4aa24f-c7e6-414e-9d0e-89626542834b';

-- 1.5% SPECIAL (real-estate affordable housing)
-- Statutory 1.5% combined = 2/3 of 2.25% gross; effective on consideration = 1%
UPDATE catalog.gst_rate_master SET
    rate_code                 = 'IN_GST_1_5',
    usage_scope               = 'TRANSACTION_RATE',
    erp_visibility            = 'CONTEXT_ONLY',
    statutory_rate_percent    = 1.50,
    effective_display_percent = 1.00,
    valuation_basis           = 'TWO_THIRDS_GROSS',
    itc_policy                = 'NO_ITC',
    conditions                = '{"real_estate_affordable": true, "notification": "03/2019-Central Tax (Rate)"}'::jsonb
WHERE id = '3e17ab19-3fbc-4f51-aa25-30c706920d7a';

-- 3% SPECIAL
UPDATE catalog.gst_rate_master SET
    rate_code                 = 'IN_GST_3',
    usage_scope               = 'TRANSACTION_RATE',
    erp_visibility            = 'GENERAL',
    statutory_rate_percent    = 3.00,
    effective_display_percent = 3.00,
    valuation_basis           = 'TRANSACTION_VALUE',
    itc_policy                = 'DEFAULT',
    conditions                = NULL
WHERE id = '9f06c0e9-ea10-4e7b-b1e3-7549f0e52fa7';

-- 5% STANDARD
UPDATE catalog.gst_rate_master SET
    rate_code                 = 'IN_GST_5',
    usage_scope               = 'TRANSACTION_RATE',
    erp_visibility            = 'GENERAL',
    statutory_rate_percent    = 5.00,
    effective_display_percent = 5.00,
    valuation_basis           = 'TRANSACTION_VALUE',
    itc_policy                = 'DEFAULT',
    conditions                = NULL
WHERE id = 'c8e603c3-f095-4378-b6fc-1006f586adb2';

-- 12% SPECIAL — bricks/tiles only (Notification 14/2025-Central Tax (Rate))
-- Must never be labelled "general" or "standard"
UPDATE catalog.gst_rate_master SET
    rate_code                 = 'IN_GST_12',
    usage_scope               = 'TRANSACTION_RATE',
    erp_visibility            = 'CONTEXT_ONLY',
    statutory_rate_percent    = 12.00,
    effective_display_percent = 12.00,
    valuation_basis           = 'TRANSACTION_VALUE',
    itc_policy                = 'DEFAULT',
    rate_name                 = 'Specified bricks/tiles only',
    conditions                = '{"notification_14_2025_scope": true, "applicable_goods": "bricks_tiles"}'::jsonb
WHERE id = '8b303ea2-faf8-4c98-bd1c-3990251fcb77';

-- 18% STANDARD
UPDATE catalog.gst_rate_master SET
    rate_code                 = 'IN_GST_18',
    usage_scope               = 'TRANSACTION_RATE',
    erp_visibility            = 'GENERAL',
    statutory_rate_percent    = 18.00,
    effective_display_percent = 18.00,
    valuation_basis           = 'TRANSACTION_VALUE',
    itc_policy                = 'DEFAULT',
    conditions                = NULL
WHERE id = '2dcadc65-093d-4d42-8cc6-653fd7bddbb9';

-- 40% SPECIAL/DEMERIT
-- Source chain: 09/2025-Central Tax (Rate) base (egazette 266209.pdf)
--   → 19/2025-Central Tax (Rate) tobacco transition eff 2026-02-01 (egazette 268978.pdf)
--   → 01/2026-Central Tax (Rate) classification amendment eff 2026-05-01 (egazette 272190.pdf)
-- 01/2026 reclassified, did NOT introduce the 40% rate itself.
UPDATE catalog.gst_rate_master SET
    rate_code                 = 'IN_GST_40',
    usage_scope               = 'TRANSACTION_RATE',
    erp_visibility            = 'GENERAL',
    statutory_rate_percent    = 40.00,
    effective_display_percent = 40.00,
    valuation_basis           = 'TRANSACTION_VALUE',
    itc_policy                = 'DEFAULT',
    source_reference          = 'BASE=09/2025-Central Tax (Rate) eff 2025-09-22 | URL=https://egazette.gov.in/WriteReadData/2025/266209.pdf | AMENDMENT_1=19/2025-Central Tax (Rate) eff 2026-02-01 | URL=https://egazette.gov.in/WriteReadData/2025/268978.pdf | AMENDMENT_2=01/2026-Central Tax (Rate) eff 2026-05-01 classification_amendment | URL=https://egazette.gov.in/WriteReadData/2026/272190.pdf | NOTE=01/2026 reclassified_scope_only_did_NOT_introduce_40pct',
    conditions                = '{"demerit": true}'::jsonb
WHERE id = '4b4e7235-6385-4a49-91d9-3994d3679cce';

-- 1% COMPOSITION
UPDATE catalog.gst_rate_master SET
    rate_code                 = 'IN_GST_COMP_1',
    usage_scope               = 'TAXPAYER_SCHEME',
    erp_visibility            = 'NEVER_LINE_ITEM',
    statutory_rate_percent    = 1.00,
    effective_display_percent = 1.00,
    valuation_basis           = 'TURNOVER',
    itc_policy                = 'NO_ITC',
    conditions                = '{"composition_scheme": true}'::jsonb
WHERE id = 'dbf0f3b1-851d-4d75-8f17-b75238af7e9b';

-- 5% COMPOSITION
UPDATE catalog.gst_rate_master SET
    rate_code                 = 'IN_GST_COMP_5',
    usage_scope               = 'TAXPAYER_SCHEME',
    erp_visibility            = 'NEVER_LINE_ITEM',
    statutory_rate_percent    = 5.00,
    effective_display_percent = 5.00,
    valuation_basis           = 'TURNOVER',
    itc_policy                = 'NO_ITC',
    conditions                = '{"composition_scheme": true}'::jsonb
WHERE id = '95617593-7464-46d4-9d4a-3a6ce7b412f4';

-- 6% COMPOSITION
UPDATE catalog.gst_rate_master SET
    rate_code                 = 'IN_GST_COMP_6',
    usage_scope               = 'TAXPAYER_SCHEME',
    erp_visibility            = 'NEVER_LINE_ITEM',
    statutory_rate_percent    = 6.00,
    effective_display_percent = 6.00,
    valuation_basis           = 'TURNOVER',
    itc_policy                = 'NO_ITC',
    conditions                = '{"composition_scheme": true}'::jsonb
WHERE id = 'bfcb4058-7160-42e4-aae4-4f57633fb248';

-- ─── 3. INSERT 2 NEW ROWS ─────────────────────────────────────────────────────

-- 0.10% — merchant-export goods procurement
-- Source: Notification 40/2017-Central Tax (Rate) dt 2017-10-23
INSERT INTO catalog.gst_rate_master (
    country_id, rate_percent, rate_name, category, is_current, status,
    notification_number, notification_date, official_source, source_reference, notes,
    effective_from, effective_to,
    rate_code, usage_scope, erp_visibility,
    statutory_rate_percent, effective_display_percent,
    valuation_basis, itc_policy, conditions
) VALUES (
    (SELECT id FROM catalog.countries WHERE iso2 = 'IN'),
    0.10,
    'Merchant-export procurement only',
    'SPECIAL',
    true,
    'ACTIVE',
    '40/2017-Central Tax (Rate)',
    '2017-10-23',
    'https://gstcouncil.gov.in/sites/default/files/gst-rates/40-2017-CGST-Rate-English.pdf',
    'SCOPE=0.05% CGST + 0.05% SGST/UTGST or 0.10% IGST on deemed exports to merchant-exporters | Circular 37/11/2018-GST applies',
    'Applicable only on supply of goods to merchant-exporters at 0.10% (0.05% CGST + 0.05% SGST/UTGST). Not a general transaction rate.',
    '2017-10-23',
    NULL,
    'IN_GST_0_10',
    'TRANSACTION_RATE',
    'CONTEXT_ONLY',
    0.10,
    0.10,
    'TRANSACTION_VALUE',
    'RESTRICTED',
    '{"merchant_export": true, "cgst": 0.05, "sgst_utgst": 0.05, "igst": 0.10}'::jsonb
);

-- 7.5% — real-estate other than affordable housing (statutory; effective = 5% on gross)
-- Source: Notification 03/2019-Central Tax (Rate) dt 2019-03-29, effective 2019-04-01
INSERT INTO catalog.gst_rate_master (
    country_id, rate_percent, rate_name, category, is_current, status,
    notification_number, notification_date, official_source, source_reference, notes,
    effective_from, effective_to,
    rate_code, usage_scope, erp_visibility,
    statutory_rate_percent, effective_display_percent,
    valuation_basis, itc_policy, conditions
) VALUES (
    (SELECT id FROM catalog.countries WHERE iso2 = 'IN'),
    7.50,
    'Real Estate (Other than affordable housing)',
    'SPECIAL',
    true,
    'ACTIVE',
    '03/2019-Central Tax (Rate)',
    '2019-03-29',
    'https://gstcouncil.gov.in/sites/default/files/gst-rates/03-2019-CGST-Rate-English.pdf',
    'STATUTORY_RATE=7.5% combined | VALUATION=2/3 of gross consideration | EFFECTIVE_RATE=5% on gross | NO_ITC=true',
    'Statutory rate 7.5% applies to 2/3 of gross consideration, yielding effective rate of 5% on full consideration. ITC not available. Not to be shown in generic item-rate list.',
    '2019-04-01',
    NULL,
    'IN_GST_7_5',
    'TRANSACTION_RATE',
    'CONTEXT_ONLY',
    7.50,
    5.00,
    'TWO_THIRDS_GROSS',
    'NO_ITC',
    '{"real_estate_other": true, "valuation_factor": 0.666667}'::jsonb
);

-- ─── 4. ADD CONSTRAINTS ───────────────────────────────────────────────────────
ALTER TABLE catalog.gst_rate_master
    ADD CONSTRAINT gst_rate_master_usage_scope_check
        CHECK (usage_scope IN ('TRANSACTION_RATE', 'TAXPAYER_SCHEME', 'HISTORICAL')),
    ADD CONSTRAINT gst_rate_master_erp_visibility_check
        CHECK (erp_visibility IN ('GENERAL', 'CONTEXT_ONLY', 'NEVER_LINE_ITEM', 'HIDDEN')),
    ADD CONSTRAINT gst_rate_master_country_rate_code_key
        UNIQUE (country_id, rate_code);

-- ─── 5. CREATE catalog.gst_rate_applications ─────────────────────────────────
CREATE TABLE catalog.gst_rate_applications (
    id                       UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    country_id               UUID        NOT NULL REFERENCES catalog.countries(id),
    application_code         TEXT        NOT NULL,
    base_rate_code           TEXT        NOT NULL,
    usage_scope              TEXT        NOT NULL CHECK (usage_scope IN ('TRANSACTION_RATE','TAXPAYER_SCHEME','HISTORICAL')),
    erp_visibility           TEXT        NOT NULL CHECK (erp_visibility IN ('GENERAL','CONTEXT_ONLY','NEVER_LINE_ITEM','HIDDEN')),
    effective_display_percent NUMERIC    NOT NULL,
    cgst_percent             NUMERIC,
    sgst_utgst_percent       NUMERIC,
    igst_percent             NUMERIC,
    valuation_factor         NUMERIC     NOT NULL DEFAULT 1.0,
    itc_policy               TEXT        NOT NULL DEFAULT 'DEFAULT',
    conditions               JSONB,
    created_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (country_id, application_code)
);

INSERT INTO catalog.gst_rate_applications
    (country_id, application_code, base_rate_code, usage_scope, erp_visibility,
     effective_display_percent, cgst_percent, sgst_utgst_percent, igst_percent,
     valuation_factor, itc_policy, conditions)
SELECT
    (SELECT id FROM catalog.countries WHERE iso2 = 'IN'),
    app_code, base_code, scope, vis, eff_pct, cgst, sgst, igst, val_f, itc, cond::jsonb
FROM (VALUES
    ('MERCHANT_EXPORT_0_10',             'IN_GST_0_10',     'TRANSACTION_RATE', 'CONTEXT_ONLY',    0.10, 0.05, 0.05, 0.10, 1.0,      'RESTRICTED', '{"merchant_export":true}'),
    ('REAL_ESTATE_AFFORDABLE_EFFECTIVE_1','IN_GST_1_5',      'TRANSACTION_RATE', 'CONTEXT_ONLY',    1.00, 0.50, 0.50, 1.00, 0.666667, 'NO_ITC',     '{"real_estate_affordable":true}'),
    ('REAL_ESTATE_OTHER_EFFECTIVE_5',    'IN_GST_7_5',      'TRANSACTION_RATE', 'CONTEXT_ONLY',    5.00, 2.50, 2.50, 5.00, 0.666667, 'NO_ITC',     '{"real_estate_other":true}'),
    ('BRICKS_TILES_12',                  'IN_GST_12',       'TRANSACTION_RATE', 'CONTEXT_ONLY',   12.00, 6.00, 6.00,12.00, 1.0,      'DEFAULT',    '{"notification_14_2025_scope":true}'),
    ('COMPOSITION_MANUFACTURER_1',       'IN_GST_COMP_1',   'TAXPAYER_SCHEME',  'NEVER_LINE_ITEM', 1.00, 0.50, 0.50, 0.00, 1.0,      'NO_ITC',     '{"composition_manufacturer":true}'),
    ('COMPOSITION_OTHER_SUPPLIER_1',     'IN_GST_COMP_1',   'TAXPAYER_SCHEME',  'NEVER_LINE_ITEM', 1.00, 0.50, 0.50, 0.00, 1.0,      'NO_ITC',     '{"composition_other_supplier":true}'),
    ('COMPOSITION_RESTAURANT_5',         'IN_GST_COMP_5',   'TAXPAYER_SCHEME',  'NEVER_LINE_ITEM', 5.00, 2.50, 2.50, 0.00, 1.0,      'NO_ITC',     '{"composition_restaurant":true}'),
    ('COMPOSITION_SERVICE_6',            'IN_GST_COMP_6',   'TAXPAYER_SCHEME',  'NEVER_LINE_ITEM', 6.00, 3.00, 3.00, 0.00, 1.0,      'NO_ITC',     '{"composition_service":true}'),
    ('NIL_RATED',                        'IN_GST_0',        'TRANSACTION_RATE', 'GENERAL',         0.00, 0.00, 0.00, 0.00, 1.0,      'DEFAULT',    '{"treatment":"NIL_RATED"}'),
    ('EXEMPT',                           'IN_GST_0',        'TRANSACTION_RATE', 'GENERAL',         0.00, 0.00, 0.00, 0.00, 1.0,      'DEFAULT',    '{"treatment":"EXEMPT"}'),
    ('ZERO_RATED',                       'IN_GST_0',        'TRANSACTION_RATE', 'GENERAL',         0.00, 0.00, 0.00, 0.00, 1.0,      'DEFAULT',    '{"treatment":"ZERO_RATED"}')
) AS t(app_code, base_code, scope, vis, eff_pct, cgst, sgst, igst, val_f, itc, cond);

-- ─── 6. RECREATE public.gst_rate_master VIEW ─────────────────────────────────
DROP VIEW IF EXISTS public.gst_rate_master;
CREATE VIEW public.gst_rate_master
    WITH (security_invoker = true)
AS
SELECT
    id,
    country_id,
    rate_percent,
    rate_name,
    category,
    is_current,
    status,
    notification_number,
    notification_date,
    official_source,
    source_reference,
    notes,
    effective_from,
    effective_to,
    created_at,
    rate_code,
    usage_scope,
    erp_visibility,
    statutory_rate_percent,
    effective_display_percent,
    valuation_basis,
    itc_policy,
    conditions
FROM catalog.gst_rate_master;

REVOKE ALL ON public.gst_rate_master FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.gst_rate_master TO service_role;

-- Also expose applications table via public view
CREATE VIEW public.gst_rate_applications
    WITH (security_invoker = true)
AS
SELECT * FROM catalog.gst_rate_applications;

REVOKE ALL ON public.gst_rate_applications FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.gst_rate_applications TO service_role;

-- ─── 7. ASSERTIONS ────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_in_id             UUID;
    v_total             INTEGER;
    v_current           INTEGER;
    v_transaction       INTEGER;
    v_composition       INTEGER;
    v_historical        INTEGER;
    v_coverage          TEXT;
    v_hist_to           DATE;
    v_40_ref            TEXT;
    v_12_name           TEXT;
    v_010_vis           TEXT;
    v_unique_codes      INTEGER;
BEGIN
    SELECT id INTO STRICT v_in_id FROM catalog.countries WHERE iso2 = 'IN';

    -- Count assertions
    SELECT count(*) INTO v_total      FROM catalog.gst_rate_master WHERE country_id = v_in_id;
    SELECT count(*) INTO v_current    FROM catalog.gst_rate_master WHERE country_id = v_in_id AND is_current = true;
    SELECT count(*) INTO v_transaction FROM catalog.gst_rate_master WHERE country_id = v_in_id AND usage_scope = 'TRANSACTION_RATE' AND is_current = true;
    SELECT count(*) INTO v_composition FROM catalog.gst_rate_master WHERE country_id = v_in_id AND usage_scope = 'TAXPAYER_SCHEME';
    SELECT count(*) INTO v_historical  FROM catalog.gst_rate_master WHERE country_id = v_in_id AND usage_scope = 'HISTORICAL';

    IF v_total      <> 14 THEN RAISE EXCEPTION 'ASSERTION FAILED: total rows = %, expected 14.', v_total; END IF;
    IF v_current    <> 13 THEN RAISE EXCEPTION 'ASSERTION FAILED: current rows = %, expected 13.', v_current; END IF;
    IF v_transaction <> 10 THEN RAISE EXCEPTION 'ASSERTION FAILED: TRANSACTION_RATE current rows = %, expected 10.', v_transaction; END IF;
    IF v_composition <> 3  THEN RAISE EXCEPTION 'ASSERTION FAILED: TAXPAYER_SCHEME rows = %, expected 3.', v_composition; END IF;
    IF v_historical  <> 1  THEN RAISE EXCEPTION 'ASSERTION FAILED: HISTORICAL rows = %, expected 1.', v_historical; END IF;

    -- 28% historical effective_to
    SELECT effective_to INTO v_hist_to FROM catalog.gst_rate_master
    WHERE country_id = v_in_id AND rate_code = 'IN_GST_HIST_28';
    IF v_hist_to <> '2026-01-31' THEN
        RAISE EXCEPTION 'ASSERTION FAILED: 28%% effective_to = %, expected 2026-01-31.', v_hist_to;
    END IF;

    -- 40% source_reference contains all three notifications
    SELECT source_reference INTO v_40_ref FROM catalog.gst_rate_master
    WHERE country_id = v_in_id AND rate_code = 'IN_GST_40';
    IF v_40_ref NOT LIKE '%09/2025%' THEN RAISE EXCEPTION 'ASSERTION FAILED: 40%% missing 09/2025 in source_reference.'; END IF;
    IF v_40_ref NOT LIKE '%19/2025%' THEN RAISE EXCEPTION 'ASSERTION FAILED: 40%% missing 19/2025 in source_reference.'; END IF;
    IF v_40_ref NOT LIKE '%01/2026%' THEN RAISE EXCEPTION 'ASSERTION FAILED: 40%% missing 01/2026 in source_reference.'; END IF;

    -- 12% rate_name must not contain "general" or "standard"
    SELECT rate_name INTO v_12_name FROM catalog.gst_rate_master
    WHERE country_id = v_in_id AND rate_code = 'IN_GST_12';
    IF lower(v_12_name) LIKE '%general%' OR lower(v_12_name) LIKE '%standard%' THEN
        RAISE EXCEPTION 'ASSERTION FAILED: 12%% rate_name contains "general" or "standard": %', v_12_name;
    END IF;

    -- 0.10% erp_visibility must be CONTEXT_ONLY
    SELECT erp_visibility INTO v_010_vis FROM catalog.gst_rate_master
    WHERE country_id = v_in_id AND rate_code = 'IN_GST_0_10';
    IF v_010_vis <> 'CONTEXT_ONLY' THEN
        RAISE EXCEPTION 'ASSERTION FAILED: 0.10%% erp_visibility = %, expected CONTEXT_ONLY.', v_010_vis;
    END IF;

    -- UNIQUE rate_code count
    SELECT count(DISTINCT rate_code) INTO v_unique_codes FROM catalog.gst_rate_master WHERE country_id = v_in_id;
    IF v_unique_codes <> 14 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: expected 14 distinct rate_codes, got %.', v_unique_codes;
    END IF;

    -- India coverage must remain UNRESOLVED
    SELECT status INTO STRICT v_coverage FROM catalog.country_tax_coverage WHERE country_id = v_in_id;
    IF v_coverage IS DISTINCT FROM 'UNRESOLVED' THEN
        RAISE EXCEPTION 'ASSERTION FAILED: India coverage = %, expected UNRESOLVED.', v_coverage;
    END IF;

    -- HSN/SAC counts must be untouched
    IF (SELECT count(*) FROM catalog.hsn_sac WHERE country_id = v_in_id AND status = 'ACTIVE' AND code_type = 'HSN') <> 21928 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: HSN count changed.';
    END IF;
    IF (SELECT count(*) FROM catalog.hsn_sac WHERE country_id = v_in_id AND status = 'ACTIVE' AND code_type = 'SAC') <> 679 THEN
        RAISE EXCEPTION 'ASSERTION FAILED: SAC count changed.';
    END IF;

    RAISE NOTICE 'ASSERTIONS OK: total=14 current=13 TRANSACTION_RATE=10 TAXPAYER_SCHEME=3 HISTORICAL=1 | 28pct_eff_to=2026-01-31 | 40pct_source_chain=present | 12pct_not_general | 0.10pct_CONTEXT_ONLY | coverage=UNRESOLVED | HSN=21928 SAC=679';
END $$;

NOTIFY pgrst, 'reload schema';
