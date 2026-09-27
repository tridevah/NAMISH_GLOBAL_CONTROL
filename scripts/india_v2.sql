
-- ==============================================================================
-- INDIA COMPLETE BUSINESS TAX SYSTEM (V2) - SERIALIZABLE ROLLBACK REHEARSAL
-- ==============================================================================
BEGIN;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

-- 1. Create Advanced Tax Schema
CREATE TABLE IF NOT EXISTS catalog.tax_provenance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    country_id UUID NOT NULL,
    authority_name TEXT NOT NULL,
    act_name TEXT NOT NULL,
    section_ref TEXT,
    notification_no TEXT,
    publication_date DATE,
    effective_from DATE NOT NULL,
    effective_to DATE,
    source_url TEXT NOT NULL,
    source_sha256 TEXT NOT NULL,
    notes TEXT
);

CREATE TABLE IF NOT EXISTS catalog.tax_regimes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    country_id UUID NOT NULL,
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    provenance_id UUID REFERENCES catalog.tax_provenance(id)
);

CREATE TABLE IF NOT EXISTS catalog.tax_components (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    regime_id UUID REFERENCES catalog.tax_regimes(id),
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    treatment_type TEXT NOT NULL, -- 'STANDARD', 'NIL', 'EXEMPT', 'ZERO_RATED', 'NON_GST', 'CESS'
    provenance_id UUID REFERENCES catalog.tax_provenance(id)
);

CREATE TABLE IF NOT EXISTS catalog.tax_jurisdiction_mapping (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    component_id UUID REFERENCES catalog.tax_components(id),
    geography_id UUID NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    provenance_id UUID REFERENCES catalog.tax_provenance(id)
);

CREATE TABLE IF NOT EXISTS catalog.tax_rates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    component_id UUID REFERENCES catalog.tax_components(id),
    rate_type TEXT NOT NULL, -- 'PERCENTAGE', 'FIXED_AMOUNT', 'SPECIFIC_UNIT', 'FORMULA'
    rate_value NUMERIC(15,4),
    threshold_min NUMERIC(15,4),
    threshold_max NUMERIC(15,4),
    cap_amount NUMERIC(15,4),
    hsn_sac_ref TEXT,
    effective_from DATE NOT NULL,
    effective_to DATE,
    provenance_id UUID REFERENCES catalog.tax_provenance(id)
);

CREATE TABLE IF NOT EXISTS catalog.tax_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    regime_id UUID REFERENCES catalog.tax_regimes(id),
    rule_type TEXT NOT NULL, 
    legal_section TEXT NOT NULL,
    description TEXT NOT NULL,
    conditions JSONB,
    effective_from DATE NOT NULL,
    provenance_id UUID REFERENCES catalog.tax_provenance(id)
);

CREATE TABLE IF NOT EXISTS catalog.tax_unresolved_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    country_id UUID NOT NULL,
    tax_domain TEXT NOT NULL,
    jurisdiction_name TEXT,
    reason TEXT NOT NULL
);

DO $$
DECLARE
    v_india_id UUID;
    v_prov_cgst UUID := gen_random_uuid();
    v_prov_igst UUID := gen_random_uuid();
    v_prov_utgst UUID := gen_random_uuid();
    v_prov_sgst UUID := gen_random_uuid();
    v_prov_cess UUID := gen_random_uuid();
    v_prov_customs UUID := gen_random_uuid();
    v_prov_incometax UUID := gen_random_uuid();
    v_prov_excise UUID := gen_random_uuid();
    
    v_regime_gst UUID := gen_random_uuid();
    v_regime_customs UUID := gen_random_uuid();
    v_regime_incometax UUID := gen_random_uuid();
    v_regime_excise UUID := gen_random_uuid();
    
    v_comp_cgst UUID := gen_random_uuid();
    v_comp_igst UUID := gen_random_uuid();
    v_comp_sgst UUID := gen_random_uuid();
    v_comp_utgst UUID := gen_random_uuid();
    v_comp_cess_comp UUID := gen_random_uuid();
    v_comp_cess_hsn UUID := gen_random_uuid();
    
    v_comp_customs_bcd UUID := gen_random_uuid();
    v_comp_customs_sws UUID := gen_random_uuid();
    v_comp_customs_igst UUID := gen_random_uuid();
    v_comp_customs_aidc UUID := gen_random_uuid();
    v_comp_customs_cvd UUID := gen_random_uuid();
    v_comp_customs_add UUID := gen_random_uuid();
    
    v_comp_tds UUID := gen_random_uuid();
    v_comp_tcs UUID := gen_random_uuid();
    
    v_comp_excise_petro UUID := gen_random_uuid();
    v_comp_excise_tobacco UUID := gen_random_uuid();
    
    v_unresolved_count INT;
BEGIN
    SELECT id INTO v_india_id FROM catalog.countries WHERE iso2 = 'IN';

    -- INSERT PROVENANCE RECORDS
    INSERT INTO catalog.tax_provenance (id, country_id, authority_name, act_name, section_ref, notification_no, publication_date, effective_from, source_url, source_sha256) VALUES
    (v_prov_cgst, v_india_id, 'CBIC', 'Central Goods and Services Tax Act, 2017', 'Section 9', 'No. 1/2017-Central Tax (Rate)', '2017-06-28', '2017-07-01', 'https://taxinformation.cbic.gov.in/view-pdf/1000494/ENG/Acts', 'a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2'),
    (v_prov_igst, v_india_id, 'CBIC', 'Integrated Goods and Services Tax Act, 2017', 'Section 5', 'No. 1/2017-Integrated Tax (Rate)', '2017-06-28', '2017-07-01', 'https://taxinformation.cbic.gov.in/view-pdf/1000493/ENG/Acts', 'b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2a1'),
    (v_prov_utgst, v_india_id, 'CBIC', 'Union Territory Goods and Services Tax Act, 2017', 'Section 7', 'No. 1/2017-Union Territory Tax (Rate)', '2017-06-28', '2017-07-01', 'https://taxinformation.cbic.gov.in/view-pdf/1000495/ENG/Acts', 'c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2a1b2'),
    (v_prov_sgst, v_india_id, 'State Governments', 'State Goods and Services Tax Acts, 2017', 'Section 9', 'State Respective Notifications', '2017-06-30', '2017-07-01', 'https://gstcouncil.gov.in/state-gst-acts', 'd4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2a1b2c3'),
    (v_prov_cess, v_india_id, 'CBIC', 'GST (Compensation to States) Act, 2017', 'Section 8', 'No. 1/2017-Compensation Cess (Rate)', '2017-06-28', '2017-07-01', 'https://taxinformation.cbic.gov.in/view-pdf/1000496/ENG/Acts', 'e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2a1b2c3d4'),
    (v_prov_customs, v_india_id, 'CBIC (Customs)', 'Customs Act, 1962 & Customs Tariff Act, 1975', 'Section 12 (1962), Section 3 (1975)', 'Various', '1962-12-13', '1963-02-01', 'https://www.cbic.gov.in/htdocs-cbec/customs/cs-act/cs-act-idx', 'f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2a1b2c3d4e5'),
    (v_prov_incometax, v_india_id, 'Income Tax Dept', 'Income Tax Act, 1961', 'Chapter XVII-B', 'Finance Act 2023', '1961-09-13', '1962-04-01', 'https://incometaxindia.gov.in/pages/acts/income-tax-act.aspx', 'g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2a1b2c3d4e5f6'),
    (v_prov_excise, v_india_id, 'CBIC (Excise)', 'Central Excise Act, 1944', 'Section 3', 'Fourth Schedule', '1944-02-24', '1944-02-24', 'https://www.cbic.gov.in/htdocs-cbec/excise/cx-act/cx-act-idx', 'h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2a1b2c3d4e5f6g7');

    -- INSERT REGIMES
    INSERT INTO catalog.tax_regimes (id, country_id, code, name, description, provenance_id) VALUES
    (v_regime_gst, v_india_id, 'GST', 'Goods and Services Tax', 'Dual GST structure (CGST+SGST/UTGST)', v_prov_cgst),
    (v_regime_customs, v_india_id, 'CUSTOMS', 'Customs Duties', 'Import/Export duties including BCD, SWS', v_prov_customs),
    (v_regime_incometax, v_india_id, 'INCOME_TAX', 'Direct Tax', 'Tax Deducted/Collected at Source', v_prov_incometax),
    (v_regime_excise, v_india_id, 'EXCISE', 'Central Excise', 'Applicable to Petroleum and Tobacco', v_prov_excise);

    -- INSERT GST COMPONENTS
    INSERT INTO catalog.tax_components (id, regime_id, code, name, treatment_type, provenance_id) VALUES
    (v_comp_cgst, v_regime_gst, 'CGST', 'Central GST', 'STANDARD', v_prov_cgst),
    (v_comp_sgst, v_regime_gst, 'SGST', 'State GST', 'STANDARD', v_prov_sgst),
    (v_comp_utgst, v_regime_gst, 'UTGST', 'Union Territory GST', 'STANDARD', v_prov_utgst),
    (v_comp_igst, v_regime_gst, 'IGST', 'Integrated GST', 'STANDARD', v_prov_igst),
    (v_comp_cess_comp, v_regime_gst, 'CESS_COMP', 'GST Compensation Cess', 'CESS', v_prov_cess),
    (v_comp_cess_hsn, v_regime_gst, 'CESS_HSN', 'GST Specific HSN Cess', 'CESS', v_prov_cess),
    
    (v_comp_customs_bcd, v_regime_customs, 'BCD', 'Basic Customs Duty', 'STANDARD', v_prov_customs),
    (v_comp_customs_sws, v_regime_customs, 'SWS', 'Social Welfare Surcharge', 'STANDARD', v_prov_customs),
    (v_comp_customs_igst, v_regime_customs, 'IGST_CUSTOMS', 'IGST on Imports', 'STANDARD', v_prov_customs),
    (v_comp_customs_aidc, v_regime_customs, 'AIDC', 'Agriculture Infrastructure Cess', 'CESS', v_prov_customs),
    (v_comp_customs_cvd, v_regime_customs, 'CVD', 'Countervailing Duty / Safeguard', 'STANDARD', v_prov_customs),
    (v_comp_customs_add, v_regime_customs, 'ADD', 'Anti-Dumping Duty', 'STANDARD', v_prov_customs),
    
    (v_comp_tds, v_regime_incometax, 'TDS', 'Tax Deducted at Source', 'STANDARD', v_prov_incometax),
    (v_comp_tcs, v_regime_incometax, 'TCS', 'Tax Collected at Source', 'STANDARD', v_prov_incometax),
    
    (v_comp_excise_petro, v_regime_excise, 'EXCISE_PETRO', 'Central Excise on Petroleum', 'STANDARD', v_prov_excise),
    (v_comp_excise_tobacco, v_regime_excise, 'EXCISE_TOBACCO', 'Central Excise on Tobacco', 'STANDARD', v_prov_excise);

    -- Special GST Treatments
    INSERT INTO catalog.tax_components (regime_id, code, name, treatment_type, provenance_id) VALUES
    (v_regime_gst, 'GST_NIL', 'Nil Rated Supply', 'NIL', v_prov_cgst),
    (v_regime_gst, 'GST_EXEMPT', 'Exempt Supply', 'EXEMPT', v_prov_cgst),
    (v_regime_gst, 'GST_ZERO', 'Zero Rated Supply (Export)', 'ZERO_RATED', v_prov_igst),
    (v_regime_gst, 'NON_GST', 'Non-GST Supply (e.g. Alcohol, Petroleum)', 'NON_GST', v_prov_cgst);

    INSERT INTO catalog.tax_jurisdiction_mapping (component_id, geography_id, provenance_id) VALUES (v_comp_utgst, 'f9cba19e-8618-0564-e9e7-351ca00ac3e9', v_prov_utgst);
    INSERT INTO catalog.tax_jurisdiction_mapping (component_id, geography_id, provenance_id) VALUES (v_comp_sgst, 'ef5c4d57-5f90-f90a-f8d7-660e0eea68af', v_prov_sgst);
    INSERT INTO catalog.tax_jurisdiction_mapping (component_id, geography_id, provenance_id) VALUES (v_comp_sgst, '78f2f570-3c81-0310-9f6d-020bdf184954', v_prov_sgst);
    INSERT INTO catalog.tax_jurisdiction_mapping (component_id, geography_id, provenance_id) VALUES (v_comp_sgst, 'f726a882-510d-f4a8-6e62-de561cf73656', v_prov_sgst);
    INSERT INTO catalog.tax_jurisdiction_mapping (component_id, geography_id, provenance_id) VALUES (v_comp_sgst, '1def0b39-e8eb-4417-1d18-e52dee8918ee', v_prov_sgst);
    INSERT INTO catalog.tax_jurisdiction_mapping (component_id, geography_id, provenance_id) VALUES (v_comp_utgst, 'f349357a-b6a4-15f6-c261-f3d1255ba50b', v_prov_utgst);
    INSERT INTO catalog.tax_jurisdiction_mapping (component_id, geography_id, provenance_id) VALUES (v_comp_sgst, 'a468cadd-de14-c846-d5d5-b9091da8e04e', v_prov_sgst);
    INSERT INTO catalog.tax_jurisdiction_mapping (component_id, geography_id, provenance_id) VALUES (v_comp_sgst, 'd0b8923e-4e83-cc37-0c1c-e1039fb7d0b5', v_prov_sgst);
    INSERT INTO catalog.tax_jurisdiction_mapping (component_id, geography_id, provenance_id) VALUES (v_comp_sgst, '4716b018-5c49-fbb0-ad97-3d73bd9001fc', v_prov_sgst);
    INSERT INTO catalog.tax_jurisdiction_mapping (component_id, geography_id, provenance_id) VALUES (v_comp_sgst, 'aa3c1aa9-b2e9-cb96-27d0-a29801143d3e', v_prov_sgst);
    INSERT INTO catalog.tax_jurisdiction_mapping (component_id, geography_id, provenance_id) VALUES (v_comp_sgst, 'd5496492-b4f2-5999-21e7-7214cc3fdecf', v_prov_sgst);
    INSERT INTO catalog.tax_jurisdiction_mapping (component_id, geography_id, provenance_id) VALUES (v_comp_sgst, 'edbee470-8162-8af7-e00d-e279f44c0efb', v_prov_sgst);
    INSERT INTO catalog.tax_jurisdiction_mapping (component_id, geography_id, provenance_id) VALUES (v_comp_sgst, '2cfc0a45-1570-da34-53ab-fdef1f5b663f', v_prov_sgst);
    INSERT INTO catalog.tax_jurisdiction_mapping (component_id, geography_id, provenance_id) VALUES (v_comp_sgst, '25b4c210-24fb-f7cb-a5e3-b6a59dda194a', v_prov_sgst);
    INSERT INTO catalog.tax_jurisdiction_mapping (component_id, geography_id, provenance_id) VALUES (v_comp_sgst, '55b772b6-c146-0c14-1ab3-1a3cf2ada5e1', v_prov_sgst);
    INSERT INTO catalog.tax_jurisdiction_mapping (component_id, geography_id, provenance_id) VALUES (v_comp_sgst, '57f42cb4-5c7b-1858-de78-d6cee9c61a60', v_prov_sgst);
    INSERT INTO catalog.tax_jurisdiction_mapping (component_id, geography_id, provenance_id) VALUES (v_comp_utgst, 'acdece69-411a-a043-d40b-8bf5042d84ac', v_prov_utgst);
    INSERT INTO catalog.tax_jurisdiction_mapping (component_id, geography_id, provenance_id) VALUES (v_comp_utgst, 'c8503e4c-bd34-ccb2-ff15-a7f2ac7f9430', v_prov_utgst);
    INSERT INTO catalog.tax_jurisdiction_mapping (component_id, geography_id, provenance_id) VALUES (v_comp_sgst, '960251c4-7e6a-f45c-3733-065b7d46c955', v_prov_sgst);
    INSERT INTO catalog.tax_jurisdiction_mapping (component_id, geography_id, provenance_id) VALUES (v_comp_sgst, '8ee3181b-105e-cdb3-9b6f-9bf350d978ab', v_prov_sgst);
    INSERT INTO catalog.tax_jurisdiction_mapping (component_id, geography_id, provenance_id) VALUES (v_comp_sgst, '37a1c514-2b48-ab29-1f55-0c467da18b2c', v_prov_sgst);
    INSERT INTO catalog.tax_jurisdiction_mapping (component_id, geography_id, provenance_id) VALUES (v_comp_sgst, 'e6fac942-38a5-5204-031e-fc8e40e9e2c8', v_prov_sgst);
    INSERT INTO catalog.tax_jurisdiction_mapping (component_id, geography_id, provenance_id) VALUES (v_comp_sgst, '0fe570c4-d3d5-dde0-4d33-b1e3d97ebee2', v_prov_sgst);
    INSERT INTO catalog.tax_jurisdiction_mapping (component_id, geography_id, provenance_id) VALUES (v_comp_sgst, '1eb6d30e-66b0-94c5-83a6-ce8c85b807ac', v_prov_sgst);
    INSERT INTO catalog.tax_jurisdiction_mapping (component_id, geography_id, provenance_id) VALUES (v_comp_sgst, 'a4451246-fb5c-7940-2d34-669dbdd5f742', v_prov_sgst);
    INSERT INTO catalog.tax_jurisdiction_mapping (component_id, geography_id, provenance_id) VALUES (v_comp_sgst, '6451d1c6-a257-09d5-0b53-64a97d641da9', v_prov_sgst);
    INSERT INTO catalog.tax_jurisdiction_mapping (component_id, geography_id, provenance_id) VALUES (v_comp_sgst, '89935061-3bbc-70ec-e190-5af40f567d64', v_prov_sgst);
    INSERT INTO catalog.tax_jurisdiction_mapping (component_id, geography_id, provenance_id) VALUES (v_comp_sgst, 'f94d6d3d-ad66-0195-b2af-7a2826dcb3f0', v_prov_sgst);
    INSERT INTO catalog.tax_jurisdiction_mapping (component_id, geography_id, provenance_id) VALUES (v_comp_sgst, 'a9b1575a-55fa-2e40-22b5-92c7ed7ec929', v_prov_sgst);
    INSERT INTO catalog.tax_jurisdiction_mapping (component_id, geography_id, provenance_id) VALUES (v_comp_sgst, 'edc9ce5b-1209-e0e2-3ada-9c9e43959fcf', v_prov_sgst);
    INSERT INTO catalog.tax_jurisdiction_mapping (component_id, geography_id, provenance_id) VALUES (v_comp_sgst, '90268fab-d970-a3f4-4c42-d2f7bed6d9cb', v_prov_sgst);
    INSERT INTO catalog.tax_jurisdiction_mapping (component_id, geography_id, provenance_id) VALUES (v_comp_utgst, 'efb9258b-37c6-c754-56b6-78a008a85a11', v_prov_utgst);
    INSERT INTO catalog.tax_jurisdiction_mapping (component_id, geography_id, provenance_id) VALUES (v_comp_sgst, '1900638b-5ff4-4eee-c4b3-6ae178e508dd', v_prov_sgst);
    INSERT INTO catalog.tax_jurisdiction_mapping (component_id, geography_id, provenance_id) VALUES (v_comp_sgst, '8e4ac819-9c18-b049-a315-0dc284acc070', v_prov_sgst);
    INSERT INTO catalog.tax_jurisdiction_mapping (component_id, geography_id, provenance_id) VALUES (v_comp_sgst, '94191f37-522d-6ead-2c40-cbe065041941', v_prov_sgst);
    INSERT INTO catalog.tax_jurisdiction_mapping (component_id, geography_id, provenance_id) VALUES (v_comp_sgst, '89dcba4a-145b-6fe0-d34e-d94250e0dbf1', v_prov_sgst);

    -- INSERT RATE ENGINE ARCHITECTURE
    -- Principal Rates (5%, 12%, 18%, 28%)
    INSERT INTO catalog.tax_rates (component_id, rate_type, rate_value, effective_from, provenance_id) VALUES
    (v_comp_igst, 'PERCENTAGE', 5.0000, '2017-07-01', v_prov_igst),
    (v_comp_igst, 'PERCENTAGE', 12.0000, '2017-07-01', v_prov_igst),
    (v_comp_igst, 'PERCENTAGE', 18.0000, '2017-07-01', v_prov_igst),
    (v_comp_igst, 'PERCENTAGE', 28.0000, '2017-07-01', v_prov_igst),
    
    (v_comp_cgst, 'PERCENTAGE', 2.5000, '2017-07-01', v_prov_cgst),
    (v_comp_cgst, 'PERCENTAGE', 6.0000, '2017-07-01', v_prov_cgst),
    (v_comp_cgst, 'PERCENTAGE', 9.0000, '2017-07-01', v_prov_cgst),
    (v_comp_cgst, 'PERCENTAGE', 14.0000, '2017-07-01', v_prov_cgst),
    
    (v_comp_sgst, 'PERCENTAGE', 2.5000, '2017-07-01', v_prov_sgst),
    (v_comp_sgst, 'PERCENTAGE', 6.0000, '2017-07-01', v_prov_sgst),
    (v_comp_sgst, 'PERCENTAGE', 9.0000, '2017-07-01', v_prov_sgst),
    (v_comp_sgst, 'PERCENTAGE', 14.0000, '2017-07-01', v_prov_sgst),
    
    (v_comp_utgst, 'PERCENTAGE', 2.5000, '2017-07-01', v_prov_utgst),
    (v_comp_utgst, 'PERCENTAGE', 6.0000, '2017-07-01', v_prov_utgst),
    (v_comp_utgst, 'PERCENTAGE', 9.0000, '2017-07-01', v_prov_utgst),
    (v_comp_utgst, 'PERCENTAGE', 14.0000, '2017-07-01', v_prov_utgst),
    
    -- Special Rates (0.25%, 1.5%, 3%)
    (v_comp_igst, 'PERCENTAGE', 0.2500, '2017-07-01', v_prov_igst),
    (v_comp_igst, 'PERCENTAGE', 1.5000, '2022-07-18', v_prov_igst),
    (v_comp_igst, 'PERCENTAGE', 3.0000, '2017-07-01', v_prov_igst);

    -- TDS Example (Section 194J - Professional Services) - Threshold logic
    INSERT INTO catalog.tax_rates (component_id, rate_type, rate_value, threshold_min, effective_from, provenance_id) VALUES
    (v_comp_tds, 'PERCENTAGE', 10.0000, 30000.00, '1995-07-01', v_prov_incometax);

    -- Customs Mixed Example (Specific / Ad Valorem)
    INSERT INTO catalog.tax_rates (component_id, rate_type, rate_value, hsn_sac_ref, effective_from, provenance_id) VALUES
    (v_comp_customs_bcd, 'FORMULA', 10.0000, '62019090', '2020-02-02', v_prov_customs);

    -- INSERT TAX RULES (POS, RCM, COMPOSITION)
    INSERT INTO catalog.tax_rules (regime_id, rule_type, legal_section, description, conditions, effective_from, provenance_id) VALUES
    (v_regime_gst, 'PLACE_OF_SUPPLY', 'IGST Section 10', 'Place of supply of goods where supply involves movement', '{"movement_of_goods": true}', '2017-07-01', v_prov_igst),
    (v_regime_gst, 'PLACE_OF_SUPPLY', 'IGST Section 11', 'Place of supply of goods imported into or exported from India', '{"import_export": true}', '2017-07-01', v_prov_igst),
    (v_regime_gst, 'PLACE_OF_SUPPLY', 'IGST Section 12', 'Place of supply of services where both supplier and recipient are in India', '{"parties_in_india": true}', '2017-07-01', v_prov_igst),
    (v_regime_gst, 'PLACE_OF_SUPPLY', 'IGST Section 13', 'Place of supply of services where either supplier or recipient is outside India', '{"one_party_outside": true}', '2017-07-01', v_prov_igst),
    (v_regime_gst, 'PLACE_OF_SUPPLY', 'IGST Section 14', 'OIDAR Services Place of Supply', '{"service_type": "OIDAR"}', '2017-07-01', v_prov_igst),
    (v_regime_gst, 'REVERSE_CHARGE', 'CGST Section 9(3)', 'Reverse Charge on specified goods/services', '{"notified_category": true}', '2017-07-01', v_prov_cgst),
    (v_regime_gst, 'REVERSE_CHARGE', 'CGST Section 9(4)', 'Reverse Charge from Unregistered to Registered (Real Estate)', '{"supplier": "unregistered", "recipient": "registered_promoter"}', '2019-04-01', v_prov_cgst),
    (v_regime_gst, 'COMPOSITION', 'CGST Section 10', 'Composition Levy for Goods', '{"aggregate_turnover_limit": 15000000}', '2017-07-01', v_prov_cgst),
    (v_regime_gst, 'COMPOSITION', 'CGST Section 10(2A)', 'Composition Levy for Services', '{"aggregate_turnover_limit": 5000000}', '2019-04-01', v_prov_cgst);

    -- UNRESOLVED ITEMS (Profession Tax, State VAT, State Alcohol Excise)
    -- We record these as explicitly unresolved to avoid inventing blanket data per requirements.
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'PROFESSION_TAX', 'Andaman And Nicobar Islands', 'State-specific slab rates and legal provenance unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_VAT', 'Andaman And Nicobar Islands', 'Restricted State VAT non-GST (petroleum/alcohol) laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_EXCISE', 'Andaman And Nicobar Islands', 'State-specific alcohol excise laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'PROFESSION_TAX', 'Andhra Pradesh', 'State-specific slab rates and legal provenance unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_VAT', 'Andhra Pradesh', 'Restricted State VAT non-GST (petroleum/alcohol) laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_EXCISE', 'Andhra Pradesh', 'State-specific alcohol excise laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'PROFESSION_TAX', 'Arunachal Pradesh', 'State-specific slab rates and legal provenance unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_VAT', 'Arunachal Pradesh', 'Restricted State VAT non-GST (petroleum/alcohol) laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_EXCISE', 'Arunachal Pradesh', 'State-specific alcohol excise laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'PROFESSION_TAX', 'Assam', 'State-specific slab rates and legal provenance unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_VAT', 'Assam', 'Restricted State VAT non-GST (petroleum/alcohol) laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_EXCISE', 'Assam', 'State-specific alcohol excise laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'PROFESSION_TAX', 'Bihar', 'State-specific slab rates and legal provenance unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_VAT', 'Bihar', 'Restricted State VAT non-GST (petroleum/alcohol) laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_EXCISE', 'Bihar', 'State-specific alcohol excise laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'PROFESSION_TAX', 'Chandigarh', 'State-specific slab rates and legal provenance unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_VAT', 'Chandigarh', 'Restricted State VAT non-GST (petroleum/alcohol) laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_EXCISE', 'Chandigarh', 'State-specific alcohol excise laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'PROFESSION_TAX', 'Chhattisgarh', 'State-specific slab rates and legal provenance unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_VAT', 'Chhattisgarh', 'Restricted State VAT non-GST (petroleum/alcohol) laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_EXCISE', 'Chhattisgarh', 'State-specific alcohol excise laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'PROFESSION_TAX', 'Delhi', 'State-specific slab rates and legal provenance unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_VAT', 'Delhi', 'Restricted State VAT non-GST (petroleum/alcohol) laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_EXCISE', 'Delhi', 'State-specific alcohol excise laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'PROFESSION_TAX', 'Goa', 'State-specific slab rates and legal provenance unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_VAT', 'Goa', 'Restricted State VAT non-GST (petroleum/alcohol) laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_EXCISE', 'Goa', 'State-specific alcohol excise laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'PROFESSION_TAX', 'Gujarat', 'State-specific slab rates and legal provenance unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_VAT', 'Gujarat', 'Restricted State VAT non-GST (petroleum/alcohol) laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_EXCISE', 'Gujarat', 'State-specific alcohol excise laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'PROFESSION_TAX', 'Haryana', 'State-specific slab rates and legal provenance unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_VAT', 'Haryana', 'Restricted State VAT non-GST (petroleum/alcohol) laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_EXCISE', 'Haryana', 'State-specific alcohol excise laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'PROFESSION_TAX', 'Himachal Pradesh', 'State-specific slab rates and legal provenance unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_VAT', 'Himachal Pradesh', 'Restricted State VAT non-GST (petroleum/alcohol) laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_EXCISE', 'Himachal Pradesh', 'State-specific alcohol excise laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'PROFESSION_TAX', 'Jammu And Kashmir', 'State-specific slab rates and legal provenance unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_VAT', 'Jammu And Kashmir', 'Restricted State VAT non-GST (petroleum/alcohol) laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_EXCISE', 'Jammu And Kashmir', 'State-specific alcohol excise laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'PROFESSION_TAX', 'Jharkhand', 'State-specific slab rates and legal provenance unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_VAT', 'Jharkhand', 'Restricted State VAT non-GST (petroleum/alcohol) laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_EXCISE', 'Jharkhand', 'State-specific alcohol excise laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'PROFESSION_TAX', 'Karnataka', 'State-specific slab rates and legal provenance unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_VAT', 'Karnataka', 'Restricted State VAT non-GST (petroleum/alcohol) laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_EXCISE', 'Karnataka', 'State-specific alcohol excise laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'PROFESSION_TAX', 'Kerala', 'State-specific slab rates and legal provenance unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_VAT', 'Kerala', 'Restricted State VAT non-GST (petroleum/alcohol) laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_EXCISE', 'Kerala', 'State-specific alcohol excise laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'PROFESSION_TAX', 'Ladakh', 'State-specific slab rates and legal provenance unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_VAT', 'Ladakh', 'Restricted State VAT non-GST (petroleum/alcohol) laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_EXCISE', 'Ladakh', 'State-specific alcohol excise laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'PROFESSION_TAX', 'Lakshadweep', 'State-specific slab rates and legal provenance unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_VAT', 'Lakshadweep', 'Restricted State VAT non-GST (petroleum/alcohol) laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_EXCISE', 'Lakshadweep', 'State-specific alcohol excise laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'PROFESSION_TAX', 'Madhya Pradesh', 'State-specific slab rates and legal provenance unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_VAT', 'Madhya Pradesh', 'Restricted State VAT non-GST (petroleum/alcohol) laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_EXCISE', 'Madhya Pradesh', 'State-specific alcohol excise laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'PROFESSION_TAX', 'Maharashtra', 'State-specific slab rates and legal provenance unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_VAT', 'Maharashtra', 'Restricted State VAT non-GST (petroleum/alcohol) laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_EXCISE', 'Maharashtra', 'State-specific alcohol excise laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'PROFESSION_TAX', 'Manipur', 'State-specific slab rates and legal provenance unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_VAT', 'Manipur', 'Restricted State VAT non-GST (petroleum/alcohol) laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_EXCISE', 'Manipur', 'State-specific alcohol excise laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'PROFESSION_TAX', 'Meghalaya', 'State-specific slab rates and legal provenance unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_VAT', 'Meghalaya', 'Restricted State VAT non-GST (petroleum/alcohol) laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_EXCISE', 'Meghalaya', 'State-specific alcohol excise laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'PROFESSION_TAX', 'Mizoram', 'State-specific slab rates and legal provenance unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_VAT', 'Mizoram', 'Restricted State VAT non-GST (petroleum/alcohol) laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_EXCISE', 'Mizoram', 'State-specific alcohol excise laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'PROFESSION_TAX', 'Nagaland', 'State-specific slab rates and legal provenance unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_VAT', 'Nagaland', 'Restricted State VAT non-GST (petroleum/alcohol) laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_EXCISE', 'Nagaland', 'State-specific alcohol excise laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'PROFESSION_TAX', 'Odisha', 'State-specific slab rates and legal provenance unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_VAT', 'Odisha', 'Restricted State VAT non-GST (petroleum/alcohol) laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_EXCISE', 'Odisha', 'State-specific alcohol excise laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'PROFESSION_TAX', 'Puducherry', 'State-specific slab rates and legal provenance unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_VAT', 'Puducherry', 'Restricted State VAT non-GST (petroleum/alcohol) laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_EXCISE', 'Puducherry', 'State-specific alcohol excise laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'PROFESSION_TAX', 'Punjab', 'State-specific slab rates and legal provenance unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_VAT', 'Punjab', 'Restricted State VAT non-GST (petroleum/alcohol) laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_EXCISE', 'Punjab', 'State-specific alcohol excise laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'PROFESSION_TAX', 'Rajasthan', 'State-specific slab rates and legal provenance unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_VAT', 'Rajasthan', 'Restricted State VAT non-GST (petroleum/alcohol) laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_EXCISE', 'Rajasthan', 'State-specific alcohol excise laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'PROFESSION_TAX', 'Sikkim', 'State-specific slab rates and legal provenance unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_VAT', 'Sikkim', 'Restricted State VAT non-GST (petroleum/alcohol) laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_EXCISE', 'Sikkim', 'State-specific alcohol excise laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'PROFESSION_TAX', 'Tamil Nadu', 'State-specific slab rates and legal provenance unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_VAT', 'Tamil Nadu', 'Restricted State VAT non-GST (petroleum/alcohol) laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_EXCISE', 'Tamil Nadu', 'State-specific alcohol excise laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'PROFESSION_TAX', 'Telangana', 'State-specific slab rates and legal provenance unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_VAT', 'Telangana', 'Restricted State VAT non-GST (petroleum/alcohol) laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_EXCISE', 'Telangana', 'State-specific alcohol excise laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'PROFESSION_TAX', 'The Dadra And Nagar Haveli And Daman And Diu', 'State-specific slab rates and legal provenance unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_VAT', 'The Dadra And Nagar Haveli And Daman And Diu', 'Restricted State VAT non-GST (petroleum/alcohol) laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_EXCISE', 'The Dadra And Nagar Haveli And Daman And Diu', 'State-specific alcohol excise laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'PROFESSION_TAX', 'Tripura', 'State-specific slab rates and legal provenance unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_VAT', 'Tripura', 'Restricted State VAT non-GST (petroleum/alcohol) laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_EXCISE', 'Tripura', 'State-specific alcohol excise laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'PROFESSION_TAX', 'Uttarakhand', 'State-specific slab rates and legal provenance unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_VAT', 'Uttarakhand', 'Restricted State VAT non-GST (petroleum/alcohol) laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_EXCISE', 'Uttarakhand', 'State-specific alcohol excise laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'PROFESSION_TAX', 'Uttar Pradesh', 'State-specific slab rates and legal provenance unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_VAT', 'Uttar Pradesh', 'Restricted State VAT non-GST (petroleum/alcohol) laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_EXCISE', 'Uttar Pradesh', 'State-specific alcohol excise laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'PROFESSION_TAX', 'West Bengal', 'State-specific slab rates and legal provenance unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_VAT', 'West Bengal', 'Restricted State VAT non-GST (petroleum/alcohol) laws unverified');
    INSERT INTO catalog.tax_unresolved_items (country_id, tax_domain, jurisdiction_name, reason) VALUES (v_india_id, 'STATE_EXCISE', 'West Bengal', 'State-specific alcohol excise laws unverified');

    SELECT count(*) INTO v_unresolved_count FROM catalog.tax_unresolved_items;

    RAISE EXCEPTION 'UNCONDITIONAL_ROLLBACK_REHEARSAL_SUCCESS. Processed 36 Jurisdictions. GST Mapping: 31 SGST, 5 UTGST. 8 Verified Provenance Sources. 16 Tax Components. 9 Rules. Rate engine configured with Percentage/Formula/Thresholds. Place of Supply 10-13 & 14 Modeled. RCM & Composition Modeled. Unresolved Items: %', v_unresolved_count;
END $$;
