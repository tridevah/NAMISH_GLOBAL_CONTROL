const fs = require('fs');
const path = require('path');

const outDir = path.join(__dirname, '../rehearsal_artifacts');
if (!fs.existsSync(outDir)) {
    fs.mkdirSync(outDir, { recursive: true });
}

const sql = `-- Migration 20260904000001: India GST Master Foundation

-- Set constraints
SET CONSTRAINTS ALL IMMEDIATE;

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
    v_jur_id UUID;
    v_tax_code_id UUID;
    v_tax_rate_id UUID;
    v_comp_set_id UUID;
    -- Arrays for State/UT
    v_sgst_states TEXT[] := ARRAY[
        'IN-AN', 'Andhra Pradesh', 'IN-AR', 'Arunachal Pradesh', 'IN-AS', 'Assam', 'IN-BR', 'Bihar', 'IN-CT', 'Chhattisgarh',
        'IN-GA', 'Goa', 'IN-GJ', 'Gujarat', 'IN-HR', 'Haryana', 'IN-HP', 'Himachal Pradesh', 'IN-JH', 'Jharkhand',
        'IN-KA', 'Karnataka', 'IN-KL', 'Kerala', 'IN-MP', 'Madhya Pradesh', 'IN-MH', 'Maharashtra', 'IN-MN', 'Manipur',
        'IN-ML', 'Meghalaya', 'IN-MZ', 'Mizoram', 'IN-NL', 'Nagaland', 'IN-OR', 'Odisha', 'IN-PB', 'Punjab',
        'IN-RJ', 'Rajasthan', 'IN-SK', 'Sikkim', 'IN-TN', 'Tamil Nadu', 'IN-TG', 'Telangana', 'IN-TR', 'Tripura',
        'IN-UP', 'Uttar Pradesh', 'IN-UT', 'Uttarakhand', 'IN-WB', 'West Bengal',
        'IN-DL', 'Delhi', 'IN-JK', 'Jammu and Kashmir', 'IN-PY', 'Puducherry'
    ];
    v_utgst_states TEXT[] := ARRAY[
        'IN-AN', 'Andaman and Nicobar Islands', 'IN-CH', 'Chandigarh', 'IN-DH', 'Dadra and Nagar Haveli and Daman and Diu',
        'IN-LA', 'Ladakh', 'IN-LD', 'Lakshadweep'
    ];
    i INT;
    v_rates NUMERIC[] := ARRAY[0, 0.25, 1.5, 3, 5, 12, 18, 40];
    v_comp_rates NUMERIC[] := ARRAY[1, 5, 6];
    v_rate NUMERIC;
BEGIN
    -- 1. Find India
    SELECT id INTO v_india_id FROM catalog.countries WHERE iso2 = 'IN';
    IF v_india_id IS NULL THEN
        RAISE EXCEPTION 'India (IN) not found in catalog.countries';
    END IF;

    -- Update coverage status
    INSERT INTO catalog.country_tax_coverage (country_id, status, checked_at)
    VALUES (v_india_id, 'VERIFIED', now())
    ON CONFLICT (country_id) DO UPDATE SET status = 'VERIFIED';

    -- 2. National Jurisdiction
    SELECT id INTO v_national_jur_id FROM catalog.jurisdictions WHERE code = 'IN_NATIONAL';
    IF v_national_jur_id IS NULL THEN
        INSERT INTO catalog.jurisdictions (code, name, country_id) VALUES ('IN_NATIONAL', 'India National', v_india_id) RETURNING id INTO v_national_jur_id;
    END IF;

    -- 3. GST Regime
    INSERT INTO catalog.tax_regimes (jurisdiction_id, country_id, code, name, status, effective_from)
    VALUES (v_national_jur_id, v_india_id, 'IN_GST', 'India GST', 'ACTIVE', '2017-07-01'::timestamptz)
    RETURNING id INTO v_gst_regime_id;

    -- 4. Components
    INSERT INTO catalog.tax_components (regime_id, code, name, status, effective_from) VALUES
    (v_gst_regime_id, 'CGST', 'Central Goods and Services Tax', 'ACTIVE', '2017-07-01'::timestamptz) RETURNING id INTO v_cgst_id;
    
    INSERT INTO catalog.tax_components (regime_id, code, name, status, effective_from) VALUES
    (v_gst_regime_id, 'SGST', 'State Goods and Services Tax', 'ACTIVE', '2017-07-01'::timestamptz) RETURNING id INTO v_sgst_id;
    
    INSERT INTO catalog.tax_components (regime_id, code, name, status, effective_from) VALUES
    (v_gst_regime_id, 'UTGST', 'Union Territory Goods and Services Tax', 'ACTIVE', '2017-07-01'::timestamptz) RETURNING id INTO v_utgst_id;
    
    INSERT INTO catalog.tax_components (regime_id, code, name, status, effective_from) VALUES
    (v_gst_regime_id, 'IGST', 'Integrated Goods and Services Tax', 'ACTIVE', '2017-07-01'::timestamptz) RETURNING id INTO v_igst_id;

    -- 5. Jurisdictions (31 SGST)
    FOR i IN 1..array_length(v_sgst_states, 1) BY 2 LOOP
        v_state_code := v_sgst_states[i];
        v_state_name := v_sgst_states[i+1];
        INSERT INTO catalog.jurisdictions (code, name, country_id)
        VALUES (v_state_code, v_state_name, v_india_id) ON CONFLICT (code) DO NOTHING;
    END LOOP;

    -- 6. Jurisdictions (5 UTGST)
    FOR i IN 1..array_length(v_utgst_states, 1) BY 2 LOOP
        v_state_code := v_utgst_states[i];
        v_state_name := v_utgst_states[i+1];
        INSERT INTO catalog.jurisdictions (code, name, country_id)
        VALUES (v_state_code, v_state_name, v_india_id) ON CONFLICT (code) DO NOTHING;
    END LOOP;

    -- 7. Tax Codes & Rates (Standard)
    FOREACH v_rate IN ARRAY v_rates LOOP
        INSERT INTO catalog.tax_codes (jurisdiction_id, regime_id, code, description, status)
        VALUES (v_national_jur_id, v_gst_regime_id, 'GST_' || REPLACE(v_rate::text, '.', '_'), 'Standard GST ' || v_rate || '%', 'ACTIVE')
        RETURNING id INTO v_tax_code_id;

        INSERT INTO catalog.tax_rates (tax_code_id, rate, effective_from)
        VALUES (v_tax_code_id, v_rate, '2017-07-01'::timestamptz)
        RETURNING id INTO v_tax_rate_id;

        -- Intra-State (CGST + SGST)
        INSERT INTO catalog.tax_rate_component_sets (tax_rate_id, code) VALUES (v_tax_rate_id, 'INTRA_STATE') RETURNING id INTO v_comp_set_id;
        INSERT INTO catalog.tax_rate_component_lines (component_set_id, component_id, calculation_method, percentage_value)
        VALUES (v_comp_set_id, v_cgst_id, 'PERCENTAGE', v_rate / 2.0);
        INSERT INTO catalog.tax_rate_component_lines (component_set_id, component_id, calculation_method, percentage_value)
        VALUES (v_comp_set_id, v_sgst_id, 'PERCENTAGE', v_rate / 2.0);

        -- Inter-State (IGST)
        INSERT INTO catalog.tax_rate_component_sets (tax_rate_id, code) VALUES (v_tax_rate_id, 'INTER_STATE') RETURNING id INTO v_comp_set_id;
        INSERT INTO catalog.tax_rate_component_lines (component_set_id, component_id, calculation_method, percentage_value)
        VALUES (v_comp_set_id, v_igst_id, 'PERCENTAGE', v_rate);
    END LOOP;

    -- Historical 28%
    INSERT INTO catalog.tax_codes (jurisdiction_id, regime_id, code, description, status)
    VALUES (v_national_jur_id, v_gst_regime_id, 'GST_28', 'Historical GST 28%', 'ACTIVE')
    RETURNING id INTO v_tax_code_id;

    INSERT INTO catalog.tax_rates (tax_code_id, rate, effective_from, effective_to)
    VALUES (v_tax_code_id, 28.0, '2017-07-01'::timestamptz, '2026-01-31 23:59:59'::timestamptz)
    RETURNING id INTO v_tax_rate_id;

    -- Composition Schemes
    FOREACH v_rate IN ARRAY v_comp_rates LOOP
        INSERT INTO catalog.tax_codes (jurisdiction_id, regime_id, code, description, status)
        VALUES (v_national_jur_id, v_gst_regime_id, 'COMP_' || v_rate, 'Composition ' || v_rate || '%', 'ACTIVE')
        RETURNING id INTO v_tax_code_id;

        INSERT INTO catalog.tax_rates (tax_code_id, rate, effective_from)
        VALUES (v_tax_code_id, v_rate, '2017-07-01'::timestamptz)
        RETURNING id INTO v_tax_rate_id;

        -- Intra-State Composition (CGST + SGST)
        INSERT INTO catalog.tax_rate_component_sets (tax_rate_id, code) VALUES (v_tax_rate_id, 'INTRA_STATE_COMP') RETURNING id INTO v_comp_set_id;
        INSERT INTO catalog.tax_rate_component_lines (component_set_id, component_id, calculation_method, percentage_value)
        VALUES (v_comp_set_id, v_cgst_id, 'PERCENTAGE', v_rate / 2.0);
        INSERT INTO catalog.tax_rate_component_lines (component_set_id, component_id, calculation_method, percentage_value)
        VALUES (v_comp_set_id, v_sgst_id, 'PERCENTAGE', v_rate / 2.0);
    END LOOP;

END $$;
`;

fs.writeFileSync(path.join(outDir, '20260904000001_india_gst_foundation.sql'), sql);
console.log('Migration generated.');
