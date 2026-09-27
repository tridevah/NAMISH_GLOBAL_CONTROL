-- Migration: India Canonical Business Tax System Rehearsal (Phase 1)
BEGIN;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

CREATE TABLE IF NOT EXISTS catalog.tax_regimes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    country_id UUID NOT NULL REFERENCES catalog.countries(id),
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    official_website TEXT,
    provenance_reference TEXT,
    status TEXT NOT NULL DEFAULT 'ACTIVE',
    effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS catalog.tax_components (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    regime_id UUID NOT NULL REFERENCES catalog.tax_regimes(id),
    jurisdiction_id UUID REFERENCES catalog.jurisdictions(id),
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    tax_type TEXT NOT NULL,
    official_website TEXT,
    provenance_reference TEXT,
    status TEXT NOT NULL DEFAULT 'ACTIVE',
    effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS catalog.tax_rates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    component_id UUID NOT NULL REFERENCES catalog.tax_components(id),
    code TEXT NOT NULL,
    rate_percent DECIMAL NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    effective_from TIMESTAMPTZ NOT NULL,
    provenance_reference TEXT,
    status TEXT NOT NULL DEFAULT 'ACTIVE'
);

CREATE TABLE IF NOT EXISTS catalog.tax_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rate_id UUID REFERENCES catalog.tax_rates(id),
    rule_type TEXT NOT NULL,
    condition_text TEXT NOT NULL,
    effective_from TIMESTAMPTZ NOT NULL,
    provenance_reference TEXT,
    status TEXT NOT NULL DEFAULT 'ACTIVE'
);

DO $$
DECLARE
  v_country_id UUID;
  v_sgst_regime_id UUID := gen_random_uuid();
  v_utgst_regime_id UUID := gen_random_uuid();
  v_cgst_regime_id UUID := gen_random_uuid();
  v_igst_regime_id UUID := gen_random_uuid();
  v_cess_regime_id UUID := gen_random_uuid();
  
  v_cgst_comp_id UUID := gen_random_uuid();
  v_igst_comp_id UUID := gen_random_uuid();
  v_cess_comp_id UUID := gen_random_uuid();

  v_scopes INT;
  v_jurs INT;
  v_comps INT;
  v_rates INT;
  v_rules INT;
BEGIN
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'IN';

  -- Regimes
  INSERT INTO catalog.tax_regimes (id, country_id, code, name, official_website, provenance_reference, status)
  VALUES (v_cgst_regime_id, v_country_id, 'CGST', 'Central GST', 'https://www.indiacode.nic.in', 'UNRESOLVED: CGST_ACT', 'UNRESOLVED');

  INSERT INTO catalog.tax_regimes (id, country_id, code, name, official_website, provenance_reference, status)
  VALUES (v_igst_regime_id, v_country_id, 'IGST', 'Integrated GST', 'https://www.indiacode.nic.in', 'UNRESOLVED: IGST_ACT', 'UNRESOLVED');

  INSERT INTO catalog.tax_regimes (id, country_id, code, name, official_website, provenance_reference, status)
  VALUES (v_sgst_regime_id, v_country_id, 'SGST', 'State GST', 'https://www.gstcouncil.gov.in/sgst-act', 'OFFICIAL_INDEX_PROVEN: HASH_71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42', 'UNRESOLVED');

  INSERT INTO catalog.tax_regimes (id, country_id, code, name, official_website, provenance_reference, status)
  VALUES (v_utgst_regime_id, v_country_id, 'UTGST', 'Union Territory GST', 'https://www.indiacode.nic.in', 'UNRESOLVED: UTGST_ACT', 'UNRESOLVED');

  INSERT INTO catalog.tax_regimes (id, country_id, code, name, official_website, provenance_reference, status)
  VALUES (v_cess_regime_id, v_country_id, 'COMPENSATION_CESS', 'GST Compensation Cess', 'https://www.indiacode.nic.in', 'UNRESOLVED: GST_COMPENSATION_CESS_ACT', 'UNRESOLVED');

  -- National Components
  INSERT INTO catalog.tax_components (id, regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
  VALUES (v_cgst_comp_id, v_cgst_regime_id, (SELECT id FROM catalog.jurisdictions WHERE code = 'IN_000000' AND country_id = v_country_id), 'CGST_NATIONAL', 'Central GST', 'GST', 'https://www.indiacode.nic.in', 'UNRESOLVED: CGST_ACT', 'UNRESOLVED');

  INSERT INTO catalog.tax_components (id, regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
  VALUES (v_igst_comp_id, v_igst_regime_id, (SELECT id FROM catalog.jurisdictions WHERE code = 'IN_000000' AND country_id = v_country_id), 'IGST_NATIONAL', 'Integrated GST', 'GST', 'https://www.indiacode.nic.in', 'UNRESOLVED: IGST_ACT', 'UNRESOLVED');

  INSERT INTO catalog.tax_components (id, regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
  VALUES (v_cess_comp_id, v_cess_regime_id, (SELECT id FROM catalog.jurisdictions WHERE code = 'IN_000000' AND country_id = v_country_id), 'CESS_NATIONAL', 'Compensation Cess', 'CESS', 'https://www.indiacode.nic.in', 'UNRESOLVED: COMP_CESS_ACT', 'UNRESOLVED');

  -- Base Unresolved Rates for CGST and IGST (Placeholder rules)
  INSERT INTO catalog.tax_rates (component_id, code, rate_percent, is_active, effective_from, provenance_reference, status)
  VALUES 
    (v_cgst_comp_id, 'CGST_9', 9.00, true, '2017-07-01', 'UNRESOLVED: CGST_RATE_NOTIF', 'UNRESOLVED'),
    (v_cgst_comp_id, 'CGST_14', 14.00, true, '2017-07-01', 'UNRESOLVED: CGST_RATE_NOTIF', 'UNRESOLVED'),
    (v_igst_comp_id, 'IGST_18', 18.00, true, '2017-07-01', 'UNRESOLVED: IGST_RATE_NOTIF', 'UNRESOLVED'),
    (v_igst_comp_id, 'IGST_28', 28.00, true, '2017-07-01', 'UNRESOLVED: IGST_RATE_NOTIF', 'UNRESOLVED');


  -- Andaman And Nicobar Islands
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
    v_st_comp UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, 'f9cba19e-8618-0564-e9e7-351ca00ac3e9');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_f9cba19e', 'Andaman And Nicobar Islands Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (id, regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_st_comp,
      v_utgst_regime_id, 
      v_jur, 
      'UTGST', 
      'Union Territory GST - Andaman And Nicobar Islands', 
      'GST', 
      'https://cbic-gst.gov.in', 
      'UNRESOLVED: UTGST_ACT',
      'UNRESOLVED'
    );

    -- Base Unresolved Rates for SGST/UTGST
    INSERT INTO catalog.tax_rates (component_id, code, rate_percent, is_active, effective_from, provenance_reference, status)
    VALUES 
      (v_st_comp, 'UTGST_9', 9.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED'),
      (v_st_comp, 'UTGST_14', 14.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED');
  END;

  -- Andhra Pradesh
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
    v_st_comp UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, 'ef5c4d57-5f90-f90a-f8d7-660e0eea68af');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_ef5c4d57', 'Andhra Pradesh Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (id, regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_st_comp,
      v_sgst_regime_id, 
      v_jur, 
      'SGST', 
      'State GST - Andhra Pradesh', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'OFFICIAL_INDEX_PROVEN: HASH_71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'UNRESOLVED'
    );

    -- Base Unresolved Rates for SGST/UTGST
    INSERT INTO catalog.tax_rates (component_id, code, rate_percent, is_active, effective_from, provenance_reference, status)
    VALUES 
      (v_st_comp, 'SGST_9', 9.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED'),
      (v_st_comp, 'SGST_14', 14.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED');
  END;

  -- Arunachal Pradesh
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
    v_st_comp UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, '78f2f570-3c81-0310-9f6d-020bdf184954');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_78f2f570', 'Arunachal Pradesh Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (id, regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_st_comp,
      v_sgst_regime_id, 
      v_jur, 
      'SGST', 
      'State GST - Arunachal Pradesh', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'OFFICIAL_INDEX_PROVEN: HASH_71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'UNRESOLVED'
    );

    -- Base Unresolved Rates for SGST/UTGST
    INSERT INTO catalog.tax_rates (component_id, code, rate_percent, is_active, effective_from, provenance_reference, status)
    VALUES 
      (v_st_comp, 'SGST_9', 9.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED'),
      (v_st_comp, 'SGST_14', 14.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED');
  END;

  -- Assam
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
    v_st_comp UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, 'f726a882-510d-f4a8-6e62-de561cf73656');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_f726a882', 'Assam Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (id, regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_st_comp,
      v_sgst_regime_id, 
      v_jur, 
      'SGST', 
      'State GST - Assam', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'OFFICIAL_INDEX_PROVEN: HASH_71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'UNRESOLVED'
    );

    -- Base Unresolved Rates for SGST/UTGST
    INSERT INTO catalog.tax_rates (component_id, code, rate_percent, is_active, effective_from, provenance_reference, status)
    VALUES 
      (v_st_comp, 'SGST_9', 9.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED'),
      (v_st_comp, 'SGST_14', 14.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED');
  END;

  -- Bihar
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
    v_st_comp UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, '1def0b39-e8eb-4417-1d18-e52dee8918ee');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_1def0b39', 'Bihar Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (id, regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_st_comp,
      v_sgst_regime_id, 
      v_jur, 
      'SGST', 
      'State GST - Bihar', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'OFFICIAL_INDEX_PROVEN: HASH_71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'UNRESOLVED'
    );

    -- Base Unresolved Rates for SGST/UTGST
    INSERT INTO catalog.tax_rates (component_id, code, rate_percent, is_active, effective_from, provenance_reference, status)
    VALUES 
      (v_st_comp, 'SGST_9', 9.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED'),
      (v_st_comp, 'SGST_14', 14.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED');
  END;

  -- Chandigarh
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
    v_st_comp UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, 'f349357a-b6a4-15f6-c261-f3d1255ba50b');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_f349357a', 'Chandigarh Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (id, regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_st_comp,
      v_utgst_regime_id, 
      v_jur, 
      'UTGST', 
      'Union Territory GST - Chandigarh', 
      'GST', 
      'https://cbic-gst.gov.in', 
      'UNRESOLVED: UTGST_ACT',
      'UNRESOLVED'
    );

    -- Base Unresolved Rates for SGST/UTGST
    INSERT INTO catalog.tax_rates (component_id, code, rate_percent, is_active, effective_from, provenance_reference, status)
    VALUES 
      (v_st_comp, 'UTGST_9', 9.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED'),
      (v_st_comp, 'UTGST_14', 14.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED');
  END;

  -- Chhattisgarh
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
    v_st_comp UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, 'a468cadd-de14-c846-d5d5-b9091da8e04e');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_a468cadd', 'Chhattisgarh Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (id, regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_st_comp,
      v_sgst_regime_id, 
      v_jur, 
      'SGST', 
      'State GST - Chhattisgarh', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'OFFICIAL_INDEX_PROVEN: HASH_71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'UNRESOLVED'
    );

    -- Base Unresolved Rates for SGST/UTGST
    INSERT INTO catalog.tax_rates (component_id, code, rate_percent, is_active, effective_from, provenance_reference, status)
    VALUES 
      (v_st_comp, 'SGST_9', 9.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED'),
      (v_st_comp, 'SGST_14', 14.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED');
  END;

  -- Delhi
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
    v_st_comp UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, 'd0b8923e-4e83-cc37-0c1c-e1039fb7d0b5');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_d0b8923e', 'Delhi Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (id, regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_st_comp,
      v_sgst_regime_id, 
      v_jur, 
      'SGST', 
      'State GST - Delhi', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'OFFICIAL_INDEX_PROVEN: HASH_71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'UNRESOLVED'
    );

    -- Base Unresolved Rates for SGST/UTGST
    INSERT INTO catalog.tax_rates (component_id, code, rate_percent, is_active, effective_from, provenance_reference, status)
    VALUES 
      (v_st_comp, 'SGST_9', 9.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED'),
      (v_st_comp, 'SGST_14', 14.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED');
  END;

  -- Goa
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
    v_st_comp UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, '4716b018-5c49-fbb0-ad97-3d73bd9001fc');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_4716b018', 'Goa Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (id, regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_st_comp,
      v_sgst_regime_id, 
      v_jur, 
      'SGST', 
      'State GST - Goa', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'OFFICIAL_INDEX_PROVEN: HASH_71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'UNRESOLVED'
    );

    -- Base Unresolved Rates for SGST/UTGST
    INSERT INTO catalog.tax_rates (component_id, code, rate_percent, is_active, effective_from, provenance_reference, status)
    VALUES 
      (v_st_comp, 'SGST_9', 9.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED'),
      (v_st_comp, 'SGST_14', 14.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED');
  END;

  -- Gujarat
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
    v_st_comp UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, 'aa3c1aa9-b2e9-cb96-27d0-a29801143d3e');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_aa3c1aa9', 'Gujarat Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (id, regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_st_comp,
      v_sgst_regime_id, 
      v_jur, 
      'SGST', 
      'State GST - Gujarat', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'OFFICIAL_INDEX_PROVEN: HASH_71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'UNRESOLVED'
    );

    -- Base Unresolved Rates for SGST/UTGST
    INSERT INTO catalog.tax_rates (component_id, code, rate_percent, is_active, effective_from, provenance_reference, status)
    VALUES 
      (v_st_comp, 'SGST_9', 9.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED'),
      (v_st_comp, 'SGST_14', 14.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED');
  END;

  -- Haryana
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
    v_st_comp UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, 'd5496492-b4f2-5999-21e7-7214cc3fdecf');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_d5496492', 'Haryana Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (id, regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_st_comp,
      v_sgst_regime_id, 
      v_jur, 
      'SGST', 
      'State GST - Haryana', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'OFFICIAL_INDEX_PROVEN: HASH_71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'UNRESOLVED'
    );

    -- Base Unresolved Rates for SGST/UTGST
    INSERT INTO catalog.tax_rates (component_id, code, rate_percent, is_active, effective_from, provenance_reference, status)
    VALUES 
      (v_st_comp, 'SGST_9', 9.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED'),
      (v_st_comp, 'SGST_14', 14.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED');
  END;

  -- Himachal Pradesh
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
    v_st_comp UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, 'edbee470-8162-8af7-e00d-e279f44c0efb');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_edbee470', 'Himachal Pradesh Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (id, regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_st_comp,
      v_sgst_regime_id, 
      v_jur, 
      'SGST', 
      'State GST - Himachal Pradesh', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'OFFICIAL_INDEX_PROVEN: HASH_71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'UNRESOLVED'
    );

    -- Base Unresolved Rates for SGST/UTGST
    INSERT INTO catalog.tax_rates (component_id, code, rate_percent, is_active, effective_from, provenance_reference, status)
    VALUES 
      (v_st_comp, 'SGST_9', 9.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED'),
      (v_st_comp, 'SGST_14', 14.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED');
  END;

  -- Jammu And Kashmir
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
    v_st_comp UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, '2cfc0a45-1570-da34-53ab-fdef1f5b663f');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_2cfc0a45', 'Jammu And Kashmir Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (id, regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_st_comp,
      v_sgst_regime_id, 
      v_jur, 
      'SGST', 
      'State GST - Jammu And Kashmir', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'OFFICIAL_INDEX_PROVEN: HASH_71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'UNRESOLVED'
    );

    -- Base Unresolved Rates for SGST/UTGST
    INSERT INTO catalog.tax_rates (component_id, code, rate_percent, is_active, effective_from, provenance_reference, status)
    VALUES 
      (v_st_comp, 'SGST_9', 9.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED'),
      (v_st_comp, 'SGST_14', 14.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED');
  END;

  -- Jharkhand
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
    v_st_comp UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, '25b4c210-24fb-f7cb-a5e3-b6a59dda194a');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_25b4c210', 'Jharkhand Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (id, regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_st_comp,
      v_sgst_regime_id, 
      v_jur, 
      'SGST', 
      'State GST - Jharkhand', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'OFFICIAL_INDEX_PROVEN: HASH_71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'UNRESOLVED'
    );

    -- Base Unresolved Rates for SGST/UTGST
    INSERT INTO catalog.tax_rates (component_id, code, rate_percent, is_active, effective_from, provenance_reference, status)
    VALUES 
      (v_st_comp, 'SGST_9', 9.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED'),
      (v_st_comp, 'SGST_14', 14.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED');
  END;

  -- Karnataka
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
    v_st_comp UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, '55b772b6-c146-0c14-1ab3-1a3cf2ada5e1');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_55b772b6', 'Karnataka Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (id, regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_st_comp,
      v_sgst_regime_id, 
      v_jur, 
      'SGST', 
      'State GST - Karnataka', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'OFFICIAL_INDEX_PROVEN: HASH_71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'UNRESOLVED'
    );

    -- Base Unresolved Rates for SGST/UTGST
    INSERT INTO catalog.tax_rates (component_id, code, rate_percent, is_active, effective_from, provenance_reference, status)
    VALUES 
      (v_st_comp, 'SGST_9', 9.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED'),
      (v_st_comp, 'SGST_14', 14.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED');
  END;

  -- Kerala
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
    v_st_comp UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, '57f42cb4-5c7b-1858-de78-d6cee9c61a60');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_57f42cb4', 'Kerala Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (id, regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_st_comp,
      v_sgst_regime_id, 
      v_jur, 
      'SGST', 
      'State GST - Kerala', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'OFFICIAL_INDEX_PROVEN: HASH_71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'UNRESOLVED'
    );

    -- Base Unresolved Rates for SGST/UTGST
    INSERT INTO catalog.tax_rates (component_id, code, rate_percent, is_active, effective_from, provenance_reference, status)
    VALUES 
      (v_st_comp, 'SGST_9', 9.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED'),
      (v_st_comp, 'SGST_14', 14.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED');
  END;

  -- Ladakh
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
    v_st_comp UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, 'acdece69-411a-a043-d40b-8bf5042d84ac');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_acdece69', 'Ladakh Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (id, regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_st_comp,
      v_utgst_regime_id, 
      v_jur, 
      'UTGST', 
      'Union Territory GST - Ladakh', 
      'GST', 
      'https://cbic-gst.gov.in', 
      'UNRESOLVED: UTGST_ACT',
      'UNRESOLVED'
    );

    -- Base Unresolved Rates for SGST/UTGST
    INSERT INTO catalog.tax_rates (component_id, code, rate_percent, is_active, effective_from, provenance_reference, status)
    VALUES 
      (v_st_comp, 'UTGST_9', 9.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED'),
      (v_st_comp, 'UTGST_14', 14.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED');
  END;

  -- Lakshadweep
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
    v_st_comp UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, 'c8503e4c-bd34-ccb2-ff15-a7f2ac7f9430');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_c8503e4c', 'Lakshadweep Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (id, regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_st_comp,
      v_utgst_regime_id, 
      v_jur, 
      'UTGST', 
      'Union Territory GST - Lakshadweep', 
      'GST', 
      'https://cbic-gst.gov.in', 
      'UNRESOLVED: UTGST_ACT',
      'UNRESOLVED'
    );

    -- Base Unresolved Rates for SGST/UTGST
    INSERT INTO catalog.tax_rates (component_id, code, rate_percent, is_active, effective_from, provenance_reference, status)
    VALUES 
      (v_st_comp, 'UTGST_9', 9.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED'),
      (v_st_comp, 'UTGST_14', 14.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED');
  END;

  -- Madhya Pradesh
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
    v_st_comp UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, '960251c4-7e6a-f45c-3733-065b7d46c955');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_960251c4', 'Madhya Pradesh Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (id, regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_st_comp,
      v_sgst_regime_id, 
      v_jur, 
      'SGST', 
      'State GST - Madhya Pradesh', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'OFFICIAL_INDEX_PROVEN: HASH_71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'UNRESOLVED'
    );

    -- Base Unresolved Rates for SGST/UTGST
    INSERT INTO catalog.tax_rates (component_id, code, rate_percent, is_active, effective_from, provenance_reference, status)
    VALUES 
      (v_st_comp, 'SGST_9', 9.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED'),
      (v_st_comp, 'SGST_14', 14.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED');
  END;

  -- Maharashtra
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
    v_st_comp UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, '8ee3181b-105e-cdb3-9b6f-9bf350d978ab');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_8ee3181b', 'Maharashtra Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (id, regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_st_comp,
      v_sgst_regime_id, 
      v_jur, 
      'SGST', 
      'State GST - Maharashtra', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'OFFICIAL_INDEX_PROVEN: HASH_71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'UNRESOLVED'
    );

    -- Base Unresolved Rates for SGST/UTGST
    INSERT INTO catalog.tax_rates (component_id, code, rate_percent, is_active, effective_from, provenance_reference, status)
    VALUES 
      (v_st_comp, 'SGST_9', 9.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED'),
      (v_st_comp, 'SGST_14', 14.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED');
  END;

  -- Manipur
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
    v_st_comp UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, '37a1c514-2b48-ab29-1f55-0c467da18b2c');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_37a1c514', 'Manipur Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (id, regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_st_comp,
      v_sgst_regime_id, 
      v_jur, 
      'SGST', 
      'State GST - Manipur', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'OFFICIAL_INDEX_PROVEN: HASH_71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'UNRESOLVED'
    );

    -- Base Unresolved Rates for SGST/UTGST
    INSERT INTO catalog.tax_rates (component_id, code, rate_percent, is_active, effective_from, provenance_reference, status)
    VALUES 
      (v_st_comp, 'SGST_9', 9.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED'),
      (v_st_comp, 'SGST_14', 14.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED');
  END;

  -- Meghalaya
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
    v_st_comp UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, 'e6fac942-38a5-5204-031e-fc8e40e9e2c8');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_e6fac942', 'Meghalaya Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (id, regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_st_comp,
      v_sgst_regime_id, 
      v_jur, 
      'SGST', 
      'State GST - Meghalaya', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'OFFICIAL_INDEX_PROVEN: HASH_71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'UNRESOLVED'
    );

    -- Base Unresolved Rates for SGST/UTGST
    INSERT INTO catalog.tax_rates (component_id, code, rate_percent, is_active, effective_from, provenance_reference, status)
    VALUES 
      (v_st_comp, 'SGST_9', 9.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED'),
      (v_st_comp, 'SGST_14', 14.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED');
  END;

  -- Mizoram
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
    v_st_comp UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, '0fe570c4-d3d5-dde0-4d33-b1e3d97ebee2');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_0fe570c4', 'Mizoram Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (id, regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_st_comp,
      v_sgst_regime_id, 
      v_jur, 
      'SGST', 
      'State GST - Mizoram', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'OFFICIAL_INDEX_PROVEN: HASH_71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'UNRESOLVED'
    );

    -- Base Unresolved Rates for SGST/UTGST
    INSERT INTO catalog.tax_rates (component_id, code, rate_percent, is_active, effective_from, provenance_reference, status)
    VALUES 
      (v_st_comp, 'SGST_9', 9.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED'),
      (v_st_comp, 'SGST_14', 14.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED');
  END;

  -- Nagaland
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
    v_st_comp UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, '1eb6d30e-66b0-94c5-83a6-ce8c85b807ac');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_1eb6d30e', 'Nagaland Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (id, regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_st_comp,
      v_sgst_regime_id, 
      v_jur, 
      'SGST', 
      'State GST - Nagaland', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'OFFICIAL_INDEX_PROVEN: HASH_71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'UNRESOLVED'
    );

    -- Base Unresolved Rates for SGST/UTGST
    INSERT INTO catalog.tax_rates (component_id, code, rate_percent, is_active, effective_from, provenance_reference, status)
    VALUES 
      (v_st_comp, 'SGST_9', 9.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED'),
      (v_st_comp, 'SGST_14', 14.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED');
  END;

  -- Odisha
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
    v_st_comp UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, 'a4451246-fb5c-7940-2d34-669dbdd5f742');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_a4451246', 'Odisha Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (id, regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_st_comp,
      v_sgst_regime_id, 
      v_jur, 
      'SGST', 
      'State GST - Odisha', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'OFFICIAL_INDEX_PROVEN: HASH_71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'UNRESOLVED'
    );

    -- Base Unresolved Rates for SGST/UTGST
    INSERT INTO catalog.tax_rates (component_id, code, rate_percent, is_active, effective_from, provenance_reference, status)
    VALUES 
      (v_st_comp, 'SGST_9', 9.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED'),
      (v_st_comp, 'SGST_14', 14.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED');
  END;

  -- Puducherry
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
    v_st_comp UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, '6451d1c6-a257-09d5-0b53-64a97d641da9');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_6451d1c6', 'Puducherry Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (id, regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_st_comp,
      v_sgst_regime_id, 
      v_jur, 
      'SGST', 
      'State GST - Puducherry', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'OFFICIAL_INDEX_PROVEN: HASH_71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'UNRESOLVED'
    );

    -- Base Unresolved Rates for SGST/UTGST
    INSERT INTO catalog.tax_rates (component_id, code, rate_percent, is_active, effective_from, provenance_reference, status)
    VALUES 
      (v_st_comp, 'SGST_9', 9.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED'),
      (v_st_comp, 'SGST_14', 14.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED');
  END;

  -- Punjab
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
    v_st_comp UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, '89935061-3bbc-70ec-e190-5af40f567d64');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_89935061', 'Punjab Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (id, regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_st_comp,
      v_sgst_regime_id, 
      v_jur, 
      'SGST', 
      'State GST - Punjab', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'OFFICIAL_INDEX_PROVEN: HASH_71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'UNRESOLVED'
    );

    -- Base Unresolved Rates for SGST/UTGST
    INSERT INTO catalog.tax_rates (component_id, code, rate_percent, is_active, effective_from, provenance_reference, status)
    VALUES 
      (v_st_comp, 'SGST_9', 9.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED'),
      (v_st_comp, 'SGST_14', 14.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED');
  END;

  -- Rajasthan
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
    v_st_comp UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, 'f94d6d3d-ad66-0195-b2af-7a2826dcb3f0');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_f94d6d3d', 'Rajasthan Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (id, regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_st_comp,
      v_sgst_regime_id, 
      v_jur, 
      'SGST', 
      'State GST - Rajasthan', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'OFFICIAL_INDEX_PROVEN: HASH_71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'UNRESOLVED'
    );

    -- Base Unresolved Rates for SGST/UTGST
    INSERT INTO catalog.tax_rates (component_id, code, rate_percent, is_active, effective_from, provenance_reference, status)
    VALUES 
      (v_st_comp, 'SGST_9', 9.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED'),
      (v_st_comp, 'SGST_14', 14.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED');
  END;

  -- Sikkim
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
    v_st_comp UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, 'a9b1575a-55fa-2e40-22b5-92c7ed7ec929');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_a9b1575a', 'Sikkim Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (id, regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_st_comp,
      v_sgst_regime_id, 
      v_jur, 
      'SGST', 
      'State GST - Sikkim', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'OFFICIAL_INDEX_PROVEN: HASH_71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'UNRESOLVED'
    );

    -- Base Unresolved Rates for SGST/UTGST
    INSERT INTO catalog.tax_rates (component_id, code, rate_percent, is_active, effective_from, provenance_reference, status)
    VALUES 
      (v_st_comp, 'SGST_9', 9.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED'),
      (v_st_comp, 'SGST_14', 14.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED');
  END;

  -- Tamil Nadu
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
    v_st_comp UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, 'edc9ce5b-1209-e0e2-3ada-9c9e43959fcf');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_edc9ce5b', 'Tamil Nadu Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (id, regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_st_comp,
      v_sgst_regime_id, 
      v_jur, 
      'SGST', 
      'State GST - Tamil Nadu', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'OFFICIAL_INDEX_PROVEN: HASH_71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'UNRESOLVED'
    );

    -- Base Unresolved Rates for SGST/UTGST
    INSERT INTO catalog.tax_rates (component_id, code, rate_percent, is_active, effective_from, provenance_reference, status)
    VALUES 
      (v_st_comp, 'SGST_9', 9.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED'),
      (v_st_comp, 'SGST_14', 14.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED');
  END;

  -- Telangana
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
    v_st_comp UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, '90268fab-d970-a3f4-4c42-d2f7bed6d9cb');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_90268fab', 'Telangana Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (id, regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_st_comp,
      v_sgst_regime_id, 
      v_jur, 
      'SGST', 
      'State GST - Telangana', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'OFFICIAL_INDEX_PROVEN: HASH_71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'UNRESOLVED'
    );

    -- Base Unresolved Rates for SGST/UTGST
    INSERT INTO catalog.tax_rates (component_id, code, rate_percent, is_active, effective_from, provenance_reference, status)
    VALUES 
      (v_st_comp, 'SGST_9', 9.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED'),
      (v_st_comp, 'SGST_14', 14.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED');
  END;

  -- The Dadra And Nagar Haveli And Daman And Diu
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
    v_st_comp UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, 'efb9258b-37c6-c754-56b6-78a008a85a11');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_efb9258b', 'The Dadra And Nagar Haveli And Daman And Diu Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (id, regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_st_comp,
      v_sgst_regime_id, 
      v_jur, 
      'SGST', 
      'State GST - The Dadra And Nagar Haveli And Daman And Diu', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'OFFICIAL_INDEX_PROVEN: HASH_71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'UNRESOLVED'
    );

    -- Base Unresolved Rates for SGST/UTGST
    INSERT INTO catalog.tax_rates (component_id, code, rate_percent, is_active, effective_from, provenance_reference, status)
    VALUES 
      (v_st_comp, 'SGST_9', 9.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED'),
      (v_st_comp, 'SGST_14', 14.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED');
  END;

  -- Tripura
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
    v_st_comp UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, '1900638b-5ff4-4eee-c4b3-6ae178e508dd');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_1900638b', 'Tripura Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (id, regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_st_comp,
      v_sgst_regime_id, 
      v_jur, 
      'SGST', 
      'State GST - Tripura', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'OFFICIAL_INDEX_PROVEN: HASH_71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'UNRESOLVED'
    );

    -- Base Unresolved Rates for SGST/UTGST
    INSERT INTO catalog.tax_rates (component_id, code, rate_percent, is_active, effective_from, provenance_reference, status)
    VALUES 
      (v_st_comp, 'SGST_9', 9.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED'),
      (v_st_comp, 'SGST_14', 14.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED');
  END;

  -- Uttarakhand
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
    v_st_comp UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, '8e4ac819-9c18-b049-a315-0dc284acc070');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_8e4ac819', 'Uttarakhand Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (id, regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_st_comp,
      v_sgst_regime_id, 
      v_jur, 
      'SGST', 
      'State GST - Uttarakhand', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'OFFICIAL_INDEX_PROVEN: HASH_71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'UNRESOLVED'
    );

    -- Base Unresolved Rates for SGST/UTGST
    INSERT INTO catalog.tax_rates (component_id, code, rate_percent, is_active, effective_from, provenance_reference, status)
    VALUES 
      (v_st_comp, 'SGST_9', 9.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED'),
      (v_st_comp, 'SGST_14', 14.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED');
  END;

  -- Uttar Pradesh
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
    v_st_comp UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, '94191f37-522d-6ead-2c40-cbe065041941');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_94191f37', 'Uttar Pradesh Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (id, regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_st_comp,
      v_sgst_regime_id, 
      v_jur, 
      'SGST', 
      'State GST - Uttar Pradesh', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'OFFICIAL_INDEX_PROVEN: HASH_71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'UNRESOLVED'
    );

    -- Base Unresolved Rates for SGST/UTGST
    INSERT INTO catalog.tax_rates (component_id, code, rate_percent, is_active, effective_from, provenance_reference, status)
    VALUES 
      (v_st_comp, 'SGST_9', 9.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED'),
      (v_st_comp, 'SGST_14', 14.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED');
  END;

  -- West Bengal
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
    v_st_comp UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, '89dcba4a-145b-6fe0-d34e-d94250e0dbf1');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_89dcba4a', 'West Bengal Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (id, regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_st_comp,
      v_sgst_regime_id, 
      v_jur, 
      'SGST', 
      'State GST - West Bengal', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'OFFICIAL_INDEX_PROVEN: HASH_71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'UNRESOLVED'
    );

    -- Base Unresolved Rates for SGST/UTGST
    INSERT INTO catalog.tax_rates (component_id, code, rate_percent, is_active, effective_from, provenance_reference, status)
    VALUES 
      (v_st_comp, 'SGST_9', 9.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED'),
      (v_st_comp, 'SGST_14', 14.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED');
  END;

  -- Verify counts
  SELECT COUNT(*) INTO v_scopes FROM catalog.scope_geographies;
  SELECT COUNT(*) INTO v_jurs FROM catalog.jurisdictions WHERE code LIKE 'IN_%' AND code != 'IN_000000';
  SELECT COUNT(*) INTO v_comps FROM catalog.tax_components;
  SELECT COUNT(*) INTO v_rates FROM catalog.tax_rates;
  SELECT COUNT(*) INTO v_rules FROM catalog.tax_rules;
  
  RAISE NOTICE 'Scope Geographies: %', v_scopes;
  RAISE NOTICE 'India Sub-Jurisdictions mapped: %', v_jurs;
  RAISE NOTICE 'Tax Components mapped: %', v_comps;
  RAISE NOTICE 'Tax Rates mapped: %', v_rates;
  RAISE NOTICE 'Tax Rules mapped: %', v_rules;
  
  RAISE EXCEPTION 'UNCONDITIONAL_ROLLBACK_REHEARSAL_SUCCESS';
END $$;
