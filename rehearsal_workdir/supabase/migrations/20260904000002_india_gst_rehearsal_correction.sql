-- Migration: India Canonical Business Tax System Rehearsal (Correction)
BEGIN;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

DO $$
DECLARE
  v_country_id UUID;
  v_scopes INT;
  v_jurs INT;
BEGIN
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'IN';

  -- Record unverified claims only in the existing coverage ledger
  UPDATE catalog.country_tax_coverage
  SET status = 'UNRESOLVED',
      reason = 'SGST index verified for jurisdictions. Regimes, components, rates, and rules (CGST, IGST, UTGST, COMP_CESS) remain unverified.',
      official_website = 'https://www.gstcouncil.gov.in/sgst-act',
      provenance_reference = 'OFFICIAL_INDEX_PROVEN: HASH_71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      updated_at = NOW()
  WHERE country_id = v_country_id;


  -- Andaman And Nicobar Islands
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, 'f9cba19e-8618-0564-e9e7-351ca00ac3e9');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_f9cba19e', 'Andaman And Nicobar Islands Tax Jurisdiction');
  END;

  -- Andhra Pradesh
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, 'ef5c4d57-5f90-f90a-f8d7-660e0eea68af');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_ef5c4d57', 'Andhra Pradesh Tax Jurisdiction');
  END;

  -- Arunachal Pradesh
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, '78f2f570-3c81-0310-9f6d-020bdf184954');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_78f2f570', 'Arunachal Pradesh Tax Jurisdiction');
  END;

  -- Assam
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, 'f726a882-510d-f4a8-6e62-de561cf73656');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_f726a882', 'Assam Tax Jurisdiction');
  END;

  -- Bihar
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, '1def0b39-e8eb-4417-1d18-e52dee8918ee');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_1def0b39', 'Bihar Tax Jurisdiction');
  END;

  -- Chandigarh
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, 'f349357a-b6a4-15f6-c261-f3d1255ba50b');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_f349357a', 'Chandigarh Tax Jurisdiction');
  END;

  -- Chhattisgarh
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, 'a468cadd-de14-c846-d5d5-b9091da8e04e');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_a468cadd', 'Chhattisgarh Tax Jurisdiction');
  END;

  -- Delhi
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, 'd0b8923e-4e83-cc37-0c1c-e1039fb7d0b5');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_d0b8923e', 'Delhi Tax Jurisdiction');
  END;

  -- Goa
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, '4716b018-5c49-fbb0-ad97-3d73bd9001fc');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_4716b018', 'Goa Tax Jurisdiction');
  END;

  -- Gujarat
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, 'aa3c1aa9-b2e9-cb96-27d0-a29801143d3e');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_aa3c1aa9', 'Gujarat Tax Jurisdiction');
  END;

  -- Haryana
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, 'd5496492-b4f2-5999-21e7-7214cc3fdecf');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_d5496492', 'Haryana Tax Jurisdiction');
  END;

  -- Himachal Pradesh
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, 'edbee470-8162-8af7-e00d-e279f44c0efb');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_edbee470', 'Himachal Pradesh Tax Jurisdiction');
  END;

  -- Jammu And Kashmir
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, '2cfc0a45-1570-da34-53ab-fdef1f5b663f');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_2cfc0a45', 'Jammu And Kashmir Tax Jurisdiction');
  END;

  -- Jharkhand
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, '25b4c210-24fb-f7cb-a5e3-b6a59dda194a');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_25b4c210', 'Jharkhand Tax Jurisdiction');
  END;

  -- Karnataka
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, '55b772b6-c146-0c14-1ab3-1a3cf2ada5e1');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_55b772b6', 'Karnataka Tax Jurisdiction');
  END;

  -- Kerala
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, '57f42cb4-5c7b-1858-de78-d6cee9c61a60');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_57f42cb4', 'Kerala Tax Jurisdiction');
  END;

  -- Ladakh
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, 'acdece69-411a-a043-d40b-8bf5042d84ac');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_acdece69', 'Ladakh Tax Jurisdiction');
  END;

  -- Lakshadweep
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, 'c8503e4c-bd34-ccb2-ff15-a7f2ac7f9430');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_c8503e4c', 'Lakshadweep Tax Jurisdiction');
  END;

  -- Madhya Pradesh
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, '960251c4-7e6a-f45c-3733-065b7d46c955');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_960251c4', 'Madhya Pradesh Tax Jurisdiction');
  END;

  -- Maharashtra
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, '8ee3181b-105e-cdb3-9b6f-9bf350d978ab');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_8ee3181b', 'Maharashtra Tax Jurisdiction');
  END;

  -- Manipur
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, '37a1c514-2b48-ab29-1f55-0c467da18b2c');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_37a1c514', 'Manipur Tax Jurisdiction');
  END;

  -- Meghalaya
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, 'e6fac942-38a5-5204-031e-fc8e40e9e2c8');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_e6fac942', 'Meghalaya Tax Jurisdiction');
  END;

  -- Mizoram
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, '0fe570c4-d3d5-dde0-4d33-b1e3d97ebee2');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_0fe570c4', 'Mizoram Tax Jurisdiction');
  END;

  -- Nagaland
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, '1eb6d30e-66b0-94c5-83a6-ce8c85b807ac');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_1eb6d30e', 'Nagaland Tax Jurisdiction');
  END;

  -- Odisha
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, 'a4451246-fb5c-7940-2d34-669dbdd5f742');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_a4451246', 'Odisha Tax Jurisdiction');
  END;

  -- Puducherry
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, '6451d1c6-a257-09d5-0b53-64a97d641da9');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_6451d1c6', 'Puducherry Tax Jurisdiction');
  END;

  -- Punjab
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, '89935061-3bbc-70ec-e190-5af40f567d64');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_89935061', 'Punjab Tax Jurisdiction');
  END;

  -- Rajasthan
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, 'f94d6d3d-ad66-0195-b2af-7a2826dcb3f0');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_f94d6d3d', 'Rajasthan Tax Jurisdiction');
  END;

  -- Sikkim
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, 'a9b1575a-55fa-2e40-22b5-92c7ed7ec929');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_a9b1575a', 'Sikkim Tax Jurisdiction');
  END;

  -- Tamil Nadu
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, 'edc9ce5b-1209-e0e2-3ada-9c9e43959fcf');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_edc9ce5b', 'Tamil Nadu Tax Jurisdiction');
  END;

  -- Telangana
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, '90268fab-d970-a3f4-4c42-d2f7bed6d9cb');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_90268fab', 'Telangana Tax Jurisdiction');
  END;

  -- The Dadra And Nagar Haveli And Daman And Diu
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, 'efb9258b-37c6-c754-56b6-78a008a85a11');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_efb9258b', 'The Dadra And Nagar Haveli And Daman And Diu Tax Jurisdiction');
  END;

  -- Tripura
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, '1900638b-5ff4-4eee-c4b3-6ae178e508dd');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_1900638b', 'Tripura Tax Jurisdiction');
  END;

  -- Uttarakhand
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, '8e4ac819-9c18-b049-a315-0dc284acc070');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_8e4ac819', 'Uttarakhand Tax Jurisdiction');
  END;

  -- Uttar Pradesh
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, '94191f37-522d-6ead-2c40-cbe065041941');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_94191f37', 'Uttar Pradesh Tax Jurisdiction');
  END;

  -- West Bengal
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, '89dcba4a-145b-6fe0-d34e-d94250e0dbf1');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_89dcba4a', 'West Bengal Tax Jurisdiction');
  END;

  -- Verify counts
  SELECT COUNT(*) INTO v_scopes FROM catalog.scope_geographies;
  SELECT COUNT(*) INTO v_jurs FROM catalog.jurisdictions WHERE code LIKE 'IN_%' AND code != 'IN_000000';
  
  RAISE NOTICE 'Scope Geographies mapped: %', v_scopes;
  RAISE NOTICE 'India Sub-Jurisdictions mapped: %', v_jurs;
  
  RAISE EXCEPTION 'UNCONDITIONAL_ROLLBACK_REHEARSAL_SUCCESS';
END $$;
