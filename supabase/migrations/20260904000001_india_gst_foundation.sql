-- Migration 20260904000001: India GST Foundation
-- Creates missing tables and seeds India GST master data.
-- Resolves India dynamically via iso2 = 'IN'.
-- No Geography or Currency DML.
-- No hardcoded UUIDs.

BEGIN;
SET CONSTRAINTS ALL DEFERRED;

-- ============================================================
-- SECTION 1: DDL — CREATE MISSING TABLES
-- ============================================================

-- 1a. tax_regimes
CREATE TABLE IF NOT EXISTS catalog.tax_regimes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    jurisdiction_id UUID REFERENCES catalog.jurisdictions(id),
    country_id UUID REFERENCES catalog.countries(id),
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    description TEXT,
    status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','INACTIVE')),
    effective_from TIMESTAMPTZ NOT NULL DEFAULT now(),
    effective_to TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 1b. tax_components
CREATE TABLE IF NOT EXISTS catalog.tax_components (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    regime_id UUID NOT NULL REFERENCES catalog.tax_regimes(id),
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','INACTIVE')),
    effective_from TIMESTAMPTZ NOT NULL DEFAULT now(),
    effective_to TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (regime_id, code)
);

-- 1c. tax_rate_component_sets
CREATE TABLE IF NOT EXISTS catalog.tax_rate_component_sets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tax_rate_id UUID NOT NULL REFERENCES catalog.tax_rates(id),
    code TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 1d. tax_rate_component_lines
CREATE TABLE IF NOT EXISTS catalog.tax_rate_component_lines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    component_set_id UUID NOT NULL REFERENCES catalog.tax_rate_component_sets(id),
    component_id UUID NOT NULL REFERENCES catalog.tax_components(id),
    calculation_method TEXT NOT NULL DEFAULT 'PERCENTAGE' CHECK (calculation_method IN ('PERCENTAGE','MONETARY','QUANTITY_BASIS')),
    percentage_value NUMERIC,
    monetary_value NUMERIC,
    quantity_basis_value NUMERIC,
    currency_code TEXT,
    uom_code TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- SECTION 2: DDL — ADD MISSING COLUMNS
-- ============================================================

-- 2a. tax_codes: add regime_id and status if missing
ALTER TABLE catalog.tax_codes
    ADD COLUMN IF NOT EXISTS regime_id UUID REFERENCES catalog.tax_regimes(id),
    ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','INACTIVE'));

-- ============================================================
-- SECTION 3: DML — INDIA GST MASTER DATA
-- ============================================================

DO $$
DECLARE
    v_india_id UUID;
    v_national_jur_id UUID;
    v_gst_regime_id UUID;
    v_cgst_id UUID;
    v_sgst_id UUID;
    v_utgst_id UUID;
    v_igst_id UUID;
    v_state_code TEXT;
    v_state_name TEXT;
    v_tax_code_id UUID;
    v_tax_rate_id UUID;
    v_comp_set_id UUID;

    -- 31 SGST jurisdictions
    v_sgst_states TEXT[] := ARRAY[
        'IN-AP', 'Andhra Pradesh',
        'IN-AR', 'Arunachal Pradesh',
        'IN-AS', 'Assam',
        'IN-BR', 'Bihar',
        'IN-CT', 'Chhattisgarh',
        'IN-GA', 'Goa',
        'IN-GJ', 'Gujarat',
        'IN-HR', 'Haryana',
        'IN-HP', 'Himachal Pradesh',
        'IN-JH', 'Jharkhand',
        'IN-KA', 'Karnataka',
        'IN-KL', 'Kerala',
        'IN-MP', 'Madhya Pradesh',
        'IN-MH', 'Maharashtra',
        'IN-MN', 'Manipur',
        'IN-ML', 'Meghalaya',
        'IN-MZ', 'Mizoram',
        'IN-NL', 'Nagaland',
        'IN-OR', 'Odisha',
        'IN-PB', 'Punjab',
        'IN-RJ', 'Rajasthan',
        'IN-SK', 'Sikkim',
        'IN-TN', 'Tamil Nadu',
        'IN-TG', 'Telangana',
        'IN-TR', 'Tripura',
        'IN-UP', 'Uttar Pradesh',
        'IN-UT', 'Uttarakhand',
        'IN-WB', 'West Bengal',
        'IN-DL', 'Delhi',
        'IN-JK', 'Jammu and Kashmir',
        'IN-PY', 'Puducherry'
    ];

    -- 5 UTGST jurisdictions
    v_utgst_states TEXT[] := ARRAY[
        'IN-AN', 'Andaman and Nicobar Islands',
        'IN-CH', 'Chandigarh',
        'IN-DH', 'Dadra and Nagar Haveli and Daman and Diu',
        'IN-LA', 'Ladakh',
        'IN-LD', 'Lakshadweep'
    ];

    i INT;
    -- 8 current selectable rates
    v_rates NUMERIC[] := ARRAY[0, 0.25, 1.5, 3, 5, 12, 18, 40];
    -- 3 composition rates
    v_comp_rates NUMERIC[] := ARRAY[1, 5, 6];
    v_rate NUMERIC;

    c_regimes INT;
    c_components INT;
    c_jurisdictions INT;
    c_rates INT;
    c_comp INT;
BEGIN
    -- ---- Resolve India ----
    SELECT id INTO v_india_id FROM catalog.countries WHERE iso2 = 'IN';
    IF v_india_id IS NULL THEN
        RAISE EXCEPTION 'India (iso2=IN) not found in catalog.countries';
    END IF;

    -- ---- Update Coverage ----
    INSERT INTO catalog.country_tax_coverage (country_id, status, checked_at)
    VALUES (v_india_id, 'VERIFIED', now())
    ON CONFLICT (country_id) DO UPDATE SET status = 'VERIFIED', checked_at = now();

    -- ---- National Jurisdiction (idempotent) ----
    SELECT id INTO v_national_jur_id FROM catalog.jurisdictions WHERE code = 'IN_NATIONAL';
    IF v_national_jur_id IS NULL THEN
        INSERT INTO catalog.jurisdictions (code, name, country_id)
        VALUES ('IN_NATIONAL', 'India National', v_india_id)
        RETURNING id INTO v_national_jur_id;
    END IF;

    -- ---- GST Regime ----
    INSERT INTO catalog.tax_regimes (jurisdiction_id, country_id, code, name, status, effective_from)
    VALUES (v_national_jur_id, v_india_id, 'IN_GST', 'India Goods and Services Tax', 'ACTIVE', '2017-07-01T00:00:00Z')
    ON CONFLICT (code) DO UPDATE SET status = 'ACTIVE'
    RETURNING id INTO v_gst_regime_id;

    -- ---- 4 Components ----
    INSERT INTO catalog.tax_components (regime_id, code, name, status, effective_from)
    VALUES (v_gst_regime_id, 'CGST', 'Central Goods and Services Tax', 'ACTIVE', '2017-07-01T00:00:00Z')
    ON CONFLICT (regime_id, code) DO UPDATE SET status = 'ACTIVE'
    RETURNING id INTO v_cgst_id;

    INSERT INTO catalog.tax_components (regime_id, code, name, status, effective_from)
    VALUES (v_gst_regime_id, 'SGST', 'State Goods and Services Tax', 'ACTIVE', '2017-07-01T00:00:00Z')
    ON CONFLICT (regime_id, code) DO UPDATE SET status = 'ACTIVE'
    RETURNING id INTO v_sgst_id;

    INSERT INTO catalog.tax_components (regime_id, code, name, status, effective_from)
    VALUES (v_gst_regime_id, 'UTGST', 'Union Territory Goods and Services Tax', 'ACTIVE', '2017-07-01T00:00:00Z')
    ON CONFLICT (regime_id, code) DO UPDATE SET status = 'ACTIVE'
    RETURNING id INTO v_utgst_id;

    INSERT INTO catalog.tax_components (regime_id, code, name, status, effective_from)
    VALUES (v_gst_regime_id, 'IGST', 'Integrated Goods and Services Tax', 'ACTIVE', '2017-07-01T00:00:00Z')
    ON CONFLICT (regime_id, code) DO UPDATE SET status = 'ACTIVE'
    RETURNING id INTO v_igst_id;

    -- ---- 31 SGST Jurisdictions ----
    FOR i IN 1..array_length(v_sgst_states, 1) BY 2 LOOP
        v_state_code := v_sgst_states[i];
        v_state_name := v_sgst_states[i+1];
        INSERT INTO catalog.jurisdictions (code, name, country_id)
        VALUES (v_state_code, v_state_name, v_india_id)
        ON CONFLICT (code) DO NOTHING;
    END LOOP;

    -- ---- 5 UTGST Jurisdictions ----
    FOR i IN 1..array_length(v_utgst_states, 1) BY 2 LOOP
        v_state_code := v_utgst_states[i];
        v_state_name := v_utgst_states[i+1];
        INSERT INTO catalog.jurisdictions (code, name, country_id)
        VALUES (v_state_code, v_state_name, v_india_id)
        ON CONFLICT (code) DO NOTHING;
    END LOOP;

    -- ---- 8 Current Selectable Rates ----
    FOREACH v_rate IN ARRAY v_rates LOOP
        -- Insert tax code
        INSERT INTO catalog.tax_codes (jurisdiction_id, regime_id, code, description, status)
        VALUES (v_national_jur_id, v_gst_regime_id,
                'GST_' || REPLACE(v_rate::text, '.', '_'),
                'India GST ' || v_rate || '% (Current)',
                'ACTIVE')
        ON CONFLICT DO NOTHING
        RETURNING id INTO v_tax_code_id;

        -- If ON CONFLICT fired, fetch existing id
        IF v_tax_code_id IS NULL THEN
            SELECT id INTO v_tax_code_id FROM catalog.tax_codes
            WHERE code = 'GST_' || REPLACE(v_rate::text, '.', '_') AND jurisdiction_id = v_national_jur_id;
        END IF;

        -- Insert rate (effective 2017-07-01, current)
        INSERT INTO catalog.tax_rates (tax_code_id, rate, effective_from)
        VALUES (v_tax_code_id, v_rate, '2017-07-01T00:00:00Z')
        RETURNING id INTO v_tax_rate_id;

        -- Intra-State: CGST + SGST (each half)
        INSERT INTO catalog.tax_rate_component_sets (tax_rate_id, code)
        VALUES (v_tax_rate_id, 'INTRA_STATE')
        RETURNING id INTO v_comp_set_id;
        INSERT INTO catalog.tax_rate_component_lines (component_set_id, component_id, calculation_method, percentage_value)
        VALUES (v_comp_set_id, v_cgst_id, 'PERCENTAGE', v_rate / 2.0);
        INSERT INTO catalog.tax_rate_component_lines (component_set_id, component_id, calculation_method, percentage_value)
        VALUES (v_comp_set_id, v_sgst_id, 'PERCENTAGE', v_rate / 2.0);

        -- Intra-UT: CGST + UTGST (each half)
        INSERT INTO catalog.tax_rate_component_sets (tax_rate_id, code)
        VALUES (v_tax_rate_id, 'INTRA_UT')
        RETURNING id INTO v_comp_set_id;
        INSERT INTO catalog.tax_rate_component_lines (component_set_id, component_id, calculation_method, percentage_value)
        VALUES (v_comp_set_id, v_cgst_id, 'PERCENTAGE', v_rate / 2.0);
        INSERT INTO catalog.tax_rate_component_lines (component_set_id, component_id, calculation_method, percentage_value)
        VALUES (v_comp_set_id, v_utgst_id, 'PERCENTAGE', v_rate / 2.0);

        -- Inter-State / Import: IGST full rate
        INSERT INTO catalog.tax_rate_component_sets (tax_rate_id, code)
        VALUES (v_tax_rate_id, 'INTER_STATE')
        RETURNING id INTO v_comp_set_id;
        INSERT INTO catalog.tax_rate_component_lines (component_set_id, component_id, calculation_method, percentage_value)
        VALUES (v_comp_set_id, v_igst_id, 'PERCENTAGE', v_rate);
    END LOOP;

    -- ---- 28% Historical (goods-schedule only, effective_to = 2026-01-31) ----
    INSERT INTO catalog.tax_codes (jurisdiction_id, regime_id, code, description, status)
    VALUES (v_national_jur_id, v_gst_regime_id, 'GST_28_HIST', 'India GST 28% (Historical goods schedule, ended 2026-01-31)', 'INACTIVE')
    ON CONFLICT DO NOTHING
    RETURNING id INTO v_tax_code_id;

    IF v_tax_code_id IS NOT NULL THEN
        INSERT INTO catalog.tax_rates (tax_code_id, rate, effective_from, effective_to)
        VALUES (v_tax_code_id, 28.0, '2017-07-01T00:00:00Z', '2026-01-31T23:59:59Z');
    END IF;

    -- ---- 3 Composition Profiles ----
    FOREACH v_rate IN ARRAY v_comp_rates LOOP
        INSERT INTO catalog.tax_codes (jurisdiction_id, regime_id, code, description, status)
        VALUES (v_national_jur_id, v_gst_regime_id,
                'COMP_' || REPLACE(v_rate::text, '.', '_'),
                'Composition Scheme ' || v_rate || '%',
                'ACTIVE')
        ON CONFLICT DO NOTHING
        RETURNING id INTO v_tax_code_id;

        IF v_tax_code_id IS NULL THEN
            SELECT id INTO v_tax_code_id FROM catalog.tax_codes
            WHERE code = 'COMP_' || REPLACE(v_rate::text, '.', '_') AND jurisdiction_id = v_national_jur_id;
        END IF;

        INSERT INTO catalog.tax_rates (tax_code_id, rate, effective_from)
        VALUES (v_tax_code_id, v_rate, '2017-07-01T00:00:00Z')
        RETURNING id INTO v_tax_rate_id;

        -- Intra-State Composition: CGST + SGST (each half)
        INSERT INTO catalog.tax_rate_component_sets (tax_rate_id, code)
        VALUES (v_tax_rate_id, 'INTRA_STATE_COMP')
        RETURNING id INTO v_comp_set_id;
        INSERT INTO catalog.tax_rate_component_lines (component_set_id, component_id, calculation_method, percentage_value)
        VALUES (v_comp_set_id, v_cgst_id, 'PERCENTAGE', v_rate / 2.0);
        INSERT INTO catalog.tax_rate_component_lines (component_set_id, component_id, calculation_method, percentage_value)
        VALUES (v_comp_set_id, v_sgst_id, 'PERCENTAGE', v_rate / 2.0);
    END LOOP;

    -- ---- Verification Counts ----
    SELECT count(*) INTO c_regimes FROM catalog.tax_regimes WHERE code = 'IN_GST';
    SELECT count(*) INTO c_components FROM catalog.tax_components WHERE regime_id = v_gst_regime_id;
    SELECT count(*) INTO c_jurisdictions FROM catalog.jurisdictions WHERE country_id = v_india_id;
    SELECT count(*) INTO c_rates FROM catalog.tax_rates tr
        JOIN catalog.tax_codes tc ON tr.tax_code_id = tc.id
        WHERE tc.regime_id = v_gst_regime_id AND tc.code NOT LIKE 'COMP_%' AND tc.code != 'GST_28_HIST';
    SELECT count(*) INTO c_comp FROM catalog.tax_rates tr
        JOIN catalog.tax_codes tc ON tr.tax_code_id = tc.id
        WHERE tc.regime_id = v_gst_regime_id AND tc.code LIKE 'COMP_%';

    RAISE NOTICE 'INDIA GST FOUNDATION COMPLETE';
    RAISE NOTICE 'GST Regimes:              %', c_regimes;
    RAISE NOTICE 'GST Components:           %', c_components;
    RAISE NOTICE 'India Jurisdictions:      %', c_jurisdictions;
    RAISE NOTICE 'Current Rate Profiles:    %', c_rates;
    RAISE NOTICE 'Composition Profiles:     %', c_comp;
END $$;

COMMIT;
