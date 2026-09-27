-- Migration 20260904000002: India GST Foundation REHEARSAL
-- Identical body to 20260904000001 but wrapped in ROLLBACK.
-- Proves counts then unconditionally aborts — never committed.

BEGIN ISOLATION LEVEL SERIALIZABLE;
SET CONSTRAINTS ALL DEFERRED;

-- ============================================================
-- SECTION 1: DDL — CREATE MISSING TABLES
-- ============================================================

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

CREATE TABLE IF NOT EXISTS catalog.tax_rate_component_sets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tax_rate_id UUID NOT NULL REFERENCES catalog.tax_rates(id),
    code TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

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

ALTER TABLE catalog.tax_codes
    ADD COLUMN IF NOT EXISTS regime_id UUID REFERENCES catalog.tax_regimes(id),
    ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','INACTIVE'));

-- ============================================================
-- SECTION 3: DML — INDIA GST MASTER DATA (REHEARSAL)
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
    v_sgst_states TEXT[] := ARRAY[
        'IN-AP', 'Andhra Pradesh', 'IN-AR', 'Arunachal Pradesh', 'IN-AS', 'Assam',
        'IN-BR', 'Bihar', 'IN-CT', 'Chhattisgarh', 'IN-GA', 'Goa', 'IN-GJ', 'Gujarat',
        'IN-HR', 'Haryana', 'IN-HP', 'Himachal Pradesh', 'IN-JH', 'Jharkhand',
        'IN-KA', 'Karnataka', 'IN-KL', 'Kerala', 'IN-MP', 'Madhya Pradesh',
        'IN-MH', 'Maharashtra', 'IN-MN', 'Manipur', 'IN-ML', 'Meghalaya',
        'IN-MZ', 'Mizoram', 'IN-NL', 'Nagaland', 'IN-OR', 'Odisha', 'IN-PB', 'Punjab',
        'IN-RJ', 'Rajasthan', 'IN-SK', 'Sikkim', 'IN-TN', 'Tamil Nadu',
        'IN-TG', 'Telangana', 'IN-TR', 'Tripura', 'IN-UP', 'Uttar Pradesh',
        'IN-UT', 'Uttarakhand', 'IN-WB', 'West Bengal', 'IN-DL', 'Delhi',
        'IN-JK', 'Jammu and Kashmir', 'IN-PY', 'Puducherry'
    ];
    v_utgst_states TEXT[] := ARRAY[
        'IN-AN', 'Andaman and Nicobar Islands', 'IN-CH', 'Chandigarh',
        'IN-DH', 'Dadra and Nagar Haveli and Daman and Diu', 'IN-LA', 'Ladakh', 'IN-LD', 'Lakshadweep'
    ];
    i INT;
    v_rates NUMERIC[] := ARRAY[0, 0.25, 1.5, 3, 5, 12, 18, 40];
    v_comp_rates NUMERIC[] := ARRAY[1, 5, 6];
    v_rate NUMERIC;
    c_regimes INT; c_components INT; c_jurisdictions INT; c_rates INT; c_comp INT;
    c_countries INT; c_currencies INT; c_geo_units INT; c_dev_blocks INT;
BEGIN
    SELECT id INTO v_india_id FROM catalog.countries WHERE iso2 = 'IN';
    IF v_india_id IS NULL THEN RAISE EXCEPTION 'India not found'; END IF;

    INSERT INTO catalog.country_tax_coverage (country_id, status, checked_at)
    VALUES (v_india_id, 'VERIFIED', now())
    ON CONFLICT (country_id) DO UPDATE SET status = 'VERIFIED', checked_at = now();

    SELECT id INTO v_national_jur_id FROM catalog.jurisdictions WHERE code = 'IN_NATIONAL';
    IF v_national_jur_id IS NULL THEN
        INSERT INTO catalog.jurisdictions (code, name, country_id)
        VALUES ('IN_NATIONAL', 'India National', v_india_id)
        RETURNING id INTO v_national_jur_id;
    END IF;

    INSERT INTO catalog.tax_regimes (jurisdiction_id, country_id, code, name, status, effective_from)
    VALUES (v_national_jur_id, v_india_id, 'IN_GST', 'India Goods and Services Tax', 'ACTIVE', '2017-07-01T00:00:00Z')
    ON CONFLICT (code) DO UPDATE SET status = 'ACTIVE'
    RETURNING id INTO v_gst_regime_id;

    INSERT INTO catalog.tax_components (regime_id, code, name, status, effective_from)
    VALUES (v_gst_regime_id, 'CGST', 'Central Goods and Services Tax', 'ACTIVE', '2017-07-01T00:00:00Z')
    ON CONFLICT (regime_id, code) DO UPDATE SET status = 'ACTIVE' RETURNING id INTO v_cgst_id;

    INSERT INTO catalog.tax_components (regime_id, code, name, status, effective_from)
    VALUES (v_gst_regime_id, 'SGST', 'State Goods and Services Tax', 'ACTIVE', '2017-07-01T00:00:00Z')
    ON CONFLICT (regime_id, code) DO UPDATE SET status = 'ACTIVE' RETURNING id INTO v_sgst_id;

    INSERT INTO catalog.tax_components (regime_id, code, name, status, effective_from)
    VALUES (v_gst_regime_id, 'UTGST', 'Union Territory Goods and Services Tax', 'ACTIVE', '2017-07-01T00:00:00Z')
    ON CONFLICT (regime_id, code) DO UPDATE SET status = 'ACTIVE' RETURNING id INTO v_utgst_id;

    INSERT INTO catalog.tax_components (regime_id, code, name, status, effective_from)
    VALUES (v_gst_regime_id, 'IGST', 'Integrated Goods and Services Tax', 'ACTIVE', '2017-07-01T00:00:00Z')
    ON CONFLICT (regime_id, code) DO UPDATE SET status = 'ACTIVE' RETURNING id INTO v_igst_id;

    FOR i IN 1..array_length(v_sgst_states, 1) BY 2 LOOP
        INSERT INTO catalog.jurisdictions (code, name, country_id) VALUES (v_sgst_states[i], v_sgst_states[i+1], v_india_id) ON CONFLICT (code) DO NOTHING;
    END LOOP;

    FOR i IN 1..array_length(v_utgst_states, 1) BY 2 LOOP
        INSERT INTO catalog.jurisdictions (code, name, country_id) VALUES (v_utgst_states[i], v_utgst_states[i+1], v_india_id) ON CONFLICT (code) DO NOTHING;
    END LOOP;

    FOREACH v_rate IN ARRAY v_rates LOOP
        INSERT INTO catalog.tax_codes (jurisdiction_id, regime_id, code, description, status)
        VALUES (v_national_jur_id, v_gst_regime_id, 'GST_' || REPLACE(v_rate::text, '.', '_'), 'India GST ' || v_rate || '%', 'ACTIVE')
        ON CONFLICT DO NOTHING RETURNING id INTO v_tax_code_id;
        IF v_tax_code_id IS NULL THEN
            SELECT id INTO v_tax_code_id FROM catalog.tax_codes WHERE code = 'GST_' || REPLACE(v_rate::text, '.', '_') AND jurisdiction_id = v_national_jur_id;
        END IF;
        INSERT INTO catalog.tax_rates (tax_code_id, rate, effective_from) VALUES (v_tax_code_id, v_rate, '2017-07-01T00:00:00Z') RETURNING id INTO v_tax_rate_id;
        INSERT INTO catalog.tax_rate_component_sets (tax_rate_id, code) VALUES (v_tax_rate_id, 'INTRA_STATE') RETURNING id INTO v_comp_set_id;
        INSERT INTO catalog.tax_rate_component_lines (component_set_id, component_id, calculation_method, percentage_value) VALUES (v_comp_set_id, v_cgst_id, 'PERCENTAGE', v_rate / 2.0);
        INSERT INTO catalog.tax_rate_component_lines (component_set_id, component_id, calculation_method, percentage_value) VALUES (v_comp_set_id, v_sgst_id, 'PERCENTAGE', v_rate / 2.0);
        INSERT INTO catalog.tax_rate_component_sets (tax_rate_id, code) VALUES (v_tax_rate_id, 'INTRA_UT') RETURNING id INTO v_comp_set_id;
        INSERT INTO catalog.tax_rate_component_lines (component_set_id, component_id, calculation_method, percentage_value) VALUES (v_comp_set_id, v_cgst_id, 'PERCENTAGE', v_rate / 2.0);
        INSERT INTO catalog.tax_rate_component_lines (component_set_id, component_id, calculation_method, percentage_value) VALUES (v_comp_set_id, v_utgst_id, 'PERCENTAGE', v_rate / 2.0);
        INSERT INTO catalog.tax_rate_component_sets (tax_rate_id, code) VALUES (v_tax_rate_id, 'INTER_STATE') RETURNING id INTO v_comp_set_id;
        INSERT INTO catalog.tax_rate_component_lines (component_set_id, component_id, calculation_method, percentage_value) VALUES (v_comp_set_id, v_igst_id, 'PERCENTAGE', v_rate);
    END LOOP;

    INSERT INTO catalog.tax_codes (jurisdiction_id, regime_id, code, description, status)
    VALUES (v_national_jur_id, v_gst_regime_id, 'GST_28_HIST', 'India GST 28% Historical', 'INACTIVE')
    ON CONFLICT DO NOTHING RETURNING id INTO v_tax_code_id;
    IF v_tax_code_id IS NOT NULL THEN
        INSERT INTO catalog.tax_rates (tax_code_id, rate, effective_from, effective_to) VALUES (v_tax_code_id, 28.0, '2017-07-01T00:00:00Z', '2026-01-31T23:59:59Z');
    END IF;

    FOREACH v_rate IN ARRAY v_comp_rates LOOP
        INSERT INTO catalog.tax_codes (jurisdiction_id, regime_id, code, description, status)
        VALUES (v_national_jur_id, v_gst_regime_id, 'COMP_' || REPLACE(v_rate::text, '.', '_'), 'Composition Scheme ' || v_rate || '%', 'ACTIVE')
        ON CONFLICT DO NOTHING RETURNING id INTO v_tax_code_id;
        IF v_tax_code_id IS NULL THEN
            SELECT id INTO v_tax_code_id FROM catalog.tax_codes WHERE code = 'COMP_' || REPLACE(v_rate::text, '.', '_') AND jurisdiction_id = v_national_jur_id;
        END IF;
        INSERT INTO catalog.tax_rates (tax_code_id, rate, effective_from) VALUES (v_tax_code_id, v_rate, '2017-07-01T00:00:00Z') RETURNING id INTO v_tax_rate_id;
        INSERT INTO catalog.tax_rate_component_sets (tax_rate_id, code) VALUES (v_tax_rate_id, 'INTRA_STATE_COMP') RETURNING id INTO v_comp_set_id;
        INSERT INTO catalog.tax_rate_component_lines (component_set_id, component_id, calculation_method, percentage_value) VALUES (v_comp_set_id, v_cgst_id, 'PERCENTAGE', v_rate / 2.0);
        INSERT INTO catalog.tax_rate_component_lines (component_set_id, component_id, calculation_method, percentage_value) VALUES (v_comp_set_id, v_sgst_id, 'PERCENTAGE', v_rate / 2.0);
    END LOOP;

    -- Verify counts
    SELECT count(*) INTO c_regimes FROM catalog.tax_regimes WHERE code = 'IN_GST';
    SELECT count(*) INTO c_components FROM catalog.tax_components WHERE regime_id = v_gst_regime_id;
    SELECT count(*) INTO c_jurisdictions FROM catalog.jurisdictions WHERE country_id = v_india_id;
    SELECT count(*) INTO c_rates FROM catalog.tax_rates tr
        JOIN catalog.tax_codes tc ON tr.tax_code_id = tc.id
        WHERE tc.regime_id = v_gst_regime_id AND tc.code NOT LIKE 'COMP_%' AND tc.code != 'GST_28_HIST';
    SELECT count(*) INTO c_comp FROM catalog.tax_rates tr
        JOIN catalog.tax_codes tc ON tr.tax_code_id = tc.id
        WHERE tc.regime_id = v_gst_regime_id AND tc.code LIKE 'COMP_%';

    -- Protected-count check
    SELECT count(*) INTO c_countries FROM catalog.countries;
    SELECT count(*) INTO c_currencies FROM catalog.currencies;
    SELECT count(*) INTO c_geo_units FROM catalog.geography_units;
    SELECT count(*) INTO c_dev_blocks FROM catalog.development_blocks;

    RAISE NOTICE '=== INDIA GST REHEARSAL COUNTS ===';
    RAISE NOTICE 'GST Regimes:              %', c_regimes;
    RAISE NOTICE 'GST Components:           %', c_components;
    RAISE NOTICE 'India Jurisdictions:      %', c_jurisdictions;
    RAISE NOTICE 'Current Rate Profiles:    %', c_rates;
    RAISE NOTICE 'Composition Profiles:     %', c_comp;
    RAISE NOTICE '=== PROTECTED COUNTS ===';
    RAISE NOTICE 'Countries:                %', c_countries;
    RAISE NOTICE 'Currencies:               %', c_currencies;
    RAISE NOTICE 'Geography Units:          %', c_geo_units;
    RAISE NOTICE 'Development Blocks:       %', c_dev_blocks;

    IF c_countries != 249 THEN RAISE EXCEPTION 'PROTECTED COUNT VIOLATION: countries=% expected 249', c_countries; END IF;
    IF c_currencies != 164 THEN RAISE EXCEPTION 'PROTECTED COUNT VIOLATION: currencies=% expected 164', c_currencies; END IF;
    IF c_geo_units  != 7912 THEN RAISE EXCEPTION 'PROTECTED COUNT VIOLATION: geography_units=% expected 7912', c_geo_units; END IF;
    IF c_dev_blocks != 7323 THEN RAISE EXCEPTION 'PROTECTED COUNT VIOLATION: development_blocks=% expected 7323', c_dev_blocks; END IF;

    -- UNCONDITIONAL ROLLBACK — this is a rehearsal
    RAISE EXCEPTION 'UNCONDITIONAL_ROLLBACK_REHEARSAL_SUCCESS';
END $$;

ROLLBACK;
