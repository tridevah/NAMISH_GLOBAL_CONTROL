-- Migration: India Canonical Business Tax System (Verified & Unresolved)
BEGIN;

DO $$
DECLARE
  v_country_id UUID;
  v_sgst_regime_id UUID := gen_random_uuid();
  v_utgst_regime_id UUID := gen_random_uuid();
  v_cgst_regime_id UUID := gen_random_uuid();
  v_igst_regime_id UUID := gen_random_uuid();
  v_cess_regime_id UUID := gen_random_uuid();
BEGIN
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'IN';

  -- Create Regimes
  -- CGST (Unresolved)
  INSERT INTO catalog.tax_regimes (id, country_id, code, name, official_website, provenance_reference, status)
  VALUES (v_cgst_regime_id, v_country_id, 'CGST', 'Central GST', 'https://cbic-gst.gov.in', 'UNRESOLVED: CGST_ACT_CURRENT', 'UNRESOLVED');

  -- IGST (Unresolved)
  INSERT INTO catalog.tax_regimes (id, country_id, code, name, official_website, provenance_reference, status)
  VALUES (v_igst_regime_id, v_country_id, 'IGST', 'Integrated GST', 'https://cbic-gst.gov.in', 'UNRESOLVED: IGST_ACT_CURRENT', 'UNRESOLVED');

  -- SGST (PROVEN)
  INSERT INTO catalog.tax_regimes (id, country_id, code, name, official_website, provenance_reference, status)
  VALUES (v_sgst_regime_id, v_country_id, 'SGST', 'State GST', 'https://www.gstcouncil.gov.in/sgst-act', 'PROVEN_HASH:71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42', 'ACTIVE');

  -- UTGST (Unresolved)
  INSERT INTO catalog.tax_regimes (id, country_id, code, name, official_website, provenance_reference, status)
  VALUES (v_utgst_regime_id, v_country_id, 'UTGST', 'Union Territory GST', 'https://cbic-gst.gov.in', 'UNRESOLVED: UTGST_ACT_CURRENT', 'UNRESOLVED');

  -- CESS (Unresolved)
  INSERT INTO catalog.tax_regimes (id, country_id, code, name, official_website, provenance_reference, status)
  VALUES (v_cess_regime_id, v_country_id, 'COMPENSATION_CESS', 'GST Compensation Cess', 'https://www.indiacode.nic.in', 'UNRESOLVED: GST_COMPENSATION_CESS_ACT', 'UNRESOLVED');


  -- Andaman And Nicobar Islands
  DECLARE
    v_scope_f9cba19e_8618_0564_e9e7_351ca00ac3e9 UUID := gen_random_uuid();
    v_jur_f9cba19e_8618_0564_e9e7_351ca00ac3e9 UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope_f9cba19e_8618_0564_e9e7_351ca00ac3e9, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope_f9cba19e_8618_0564_e9e7_351ca00ac3e9, 'f9cba19e-8618-0564-e9e7-351ca00ac3e9');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur_f9cba19e_8618_0564_e9e7_351ca00ac3e9, v_country_id, v_scope_f9cba19e_8618_0564_e9e7_351ca00ac3e9, 'IN_f9cba19e', 'Andaman And Nicobar Islands Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_utgst_regime_id, 
      v_jur_f9cba19e_8618_0564_e9e7_351ca00ac3e9, 
      'UTGST', 
      'Union Territory GST - Andaman And Nicobar Islands', 
      'GST', 
      'https://cbic-gst.gov.in', 
      'UNRESOLVED: UTGST_ACT_CURRENT',
      'UNRESOLVED'
    );
  END;

  -- Andhra Pradesh
  DECLARE
    v_scope_ef5c4d57_5f90_f90a_f8d7_660e0eea68af UUID := gen_random_uuid();
    v_jur_ef5c4d57_5f90_f90a_f8d7_660e0eea68af UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope_ef5c4d57_5f90_f90a_f8d7_660e0eea68af, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope_ef5c4d57_5f90_f90a_f8d7_660e0eea68af, 'ef5c4d57-5f90-f90a-f8d7-660e0eea68af');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur_ef5c4d57_5f90_f90a_f8d7_660e0eea68af, v_country_id, v_scope_ef5c4d57_5f90_f90a_f8d7_660e0eea68af, 'IN_ef5c4d57', 'Andhra Pradesh Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_sgst_regime_id, 
      v_jur_ef5c4d57_5f90_f90a_f8d7_660e0eea68af, 
      'SGST', 
      'State GST - Andhra Pradesh', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'PROVEN_HASH:71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'ACTIVE'
    );
  END;

  -- Arunachal Pradesh
  DECLARE
    v_scope_78f2f570_3c81_0310_9f6d_020bdf184954 UUID := gen_random_uuid();
    v_jur_78f2f570_3c81_0310_9f6d_020bdf184954 UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope_78f2f570_3c81_0310_9f6d_020bdf184954, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope_78f2f570_3c81_0310_9f6d_020bdf184954, '78f2f570-3c81-0310-9f6d-020bdf184954');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur_78f2f570_3c81_0310_9f6d_020bdf184954, v_country_id, v_scope_78f2f570_3c81_0310_9f6d_020bdf184954, 'IN_78f2f570', 'Arunachal Pradesh Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_sgst_regime_id, 
      v_jur_78f2f570_3c81_0310_9f6d_020bdf184954, 
      'SGST', 
      'State GST - Arunachal Pradesh', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'PROVEN_HASH:71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'ACTIVE'
    );
  END;

  -- Assam
  DECLARE
    v_scope_f726a882_510d_f4a8_6e62_de561cf73656 UUID := gen_random_uuid();
    v_jur_f726a882_510d_f4a8_6e62_de561cf73656 UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope_f726a882_510d_f4a8_6e62_de561cf73656, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope_f726a882_510d_f4a8_6e62_de561cf73656, 'f726a882-510d-f4a8-6e62-de561cf73656');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur_f726a882_510d_f4a8_6e62_de561cf73656, v_country_id, v_scope_f726a882_510d_f4a8_6e62_de561cf73656, 'IN_f726a882', 'Assam Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_sgst_regime_id, 
      v_jur_f726a882_510d_f4a8_6e62_de561cf73656, 
      'SGST', 
      'State GST - Assam', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'PROVEN_HASH:71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'ACTIVE'
    );
  END;

  -- Bihar
  DECLARE
    v_scope_1def0b39_e8eb_4417_1d18_e52dee8918ee UUID := gen_random_uuid();
    v_jur_1def0b39_e8eb_4417_1d18_e52dee8918ee UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope_1def0b39_e8eb_4417_1d18_e52dee8918ee, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope_1def0b39_e8eb_4417_1d18_e52dee8918ee, '1def0b39-e8eb-4417-1d18-e52dee8918ee');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur_1def0b39_e8eb_4417_1d18_e52dee8918ee, v_country_id, v_scope_1def0b39_e8eb_4417_1d18_e52dee8918ee, 'IN_1def0b39', 'Bihar Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_sgst_regime_id, 
      v_jur_1def0b39_e8eb_4417_1d18_e52dee8918ee, 
      'SGST', 
      'State GST - Bihar', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'PROVEN_HASH:71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'ACTIVE'
    );
  END;

  -- Chandigarh
  DECLARE
    v_scope_f349357a_b6a4_15f6_c261_f3d1255ba50b UUID := gen_random_uuid();
    v_jur_f349357a_b6a4_15f6_c261_f3d1255ba50b UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope_f349357a_b6a4_15f6_c261_f3d1255ba50b, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope_f349357a_b6a4_15f6_c261_f3d1255ba50b, 'f349357a-b6a4-15f6-c261-f3d1255ba50b');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur_f349357a_b6a4_15f6_c261_f3d1255ba50b, v_country_id, v_scope_f349357a_b6a4_15f6_c261_f3d1255ba50b, 'IN_f349357a', 'Chandigarh Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_utgst_regime_id, 
      v_jur_f349357a_b6a4_15f6_c261_f3d1255ba50b, 
      'UTGST', 
      'Union Territory GST - Chandigarh', 
      'GST', 
      'https://cbic-gst.gov.in', 
      'UNRESOLVED: UTGST_ACT_CURRENT',
      'UNRESOLVED'
    );
  END;

  -- Chhattisgarh
  DECLARE
    v_scope_a468cadd_de14_c846_d5d5_b9091da8e04e UUID := gen_random_uuid();
    v_jur_a468cadd_de14_c846_d5d5_b9091da8e04e UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope_a468cadd_de14_c846_d5d5_b9091da8e04e, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope_a468cadd_de14_c846_d5d5_b9091da8e04e, 'a468cadd-de14-c846-d5d5-b9091da8e04e');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur_a468cadd_de14_c846_d5d5_b9091da8e04e, v_country_id, v_scope_a468cadd_de14_c846_d5d5_b9091da8e04e, 'IN_a468cadd', 'Chhattisgarh Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_sgst_regime_id, 
      v_jur_a468cadd_de14_c846_d5d5_b9091da8e04e, 
      'SGST', 
      'State GST - Chhattisgarh', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'PROVEN_HASH:71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'ACTIVE'
    );
  END;

  -- Delhi
  DECLARE
    v_scope_d0b8923e_4e83_cc37_0c1c_e1039fb7d0b5 UUID := gen_random_uuid();
    v_jur_d0b8923e_4e83_cc37_0c1c_e1039fb7d0b5 UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope_d0b8923e_4e83_cc37_0c1c_e1039fb7d0b5, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope_d0b8923e_4e83_cc37_0c1c_e1039fb7d0b5, 'd0b8923e-4e83-cc37-0c1c-e1039fb7d0b5');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur_d0b8923e_4e83_cc37_0c1c_e1039fb7d0b5, v_country_id, v_scope_d0b8923e_4e83_cc37_0c1c_e1039fb7d0b5, 'IN_d0b8923e', 'Delhi Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_sgst_regime_id, 
      v_jur_d0b8923e_4e83_cc37_0c1c_e1039fb7d0b5, 
      'SGST', 
      'State GST - Delhi', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'PROVEN_HASH:71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'ACTIVE'
    );
  END;

  -- Goa
  DECLARE
    v_scope_4716b018_5c49_fbb0_ad97_3d73bd9001fc UUID := gen_random_uuid();
    v_jur_4716b018_5c49_fbb0_ad97_3d73bd9001fc UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope_4716b018_5c49_fbb0_ad97_3d73bd9001fc, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope_4716b018_5c49_fbb0_ad97_3d73bd9001fc, '4716b018-5c49-fbb0-ad97-3d73bd9001fc');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur_4716b018_5c49_fbb0_ad97_3d73bd9001fc, v_country_id, v_scope_4716b018_5c49_fbb0_ad97_3d73bd9001fc, 'IN_4716b018', 'Goa Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_sgst_regime_id, 
      v_jur_4716b018_5c49_fbb0_ad97_3d73bd9001fc, 
      'SGST', 
      'State GST - Goa', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'PROVEN_HASH:71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'ACTIVE'
    );
  END;

  -- Gujarat
  DECLARE
    v_scope_aa3c1aa9_b2e9_cb96_27d0_a29801143d3e UUID := gen_random_uuid();
    v_jur_aa3c1aa9_b2e9_cb96_27d0_a29801143d3e UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope_aa3c1aa9_b2e9_cb96_27d0_a29801143d3e, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope_aa3c1aa9_b2e9_cb96_27d0_a29801143d3e, 'aa3c1aa9-b2e9-cb96-27d0-a29801143d3e');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur_aa3c1aa9_b2e9_cb96_27d0_a29801143d3e, v_country_id, v_scope_aa3c1aa9_b2e9_cb96_27d0_a29801143d3e, 'IN_aa3c1aa9', 'Gujarat Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_sgst_regime_id, 
      v_jur_aa3c1aa9_b2e9_cb96_27d0_a29801143d3e, 
      'SGST', 
      'State GST - Gujarat', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'PROVEN_HASH:71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'ACTIVE'
    );
  END;

  -- Haryana
  DECLARE
    v_scope_d5496492_b4f2_5999_21e7_7214cc3fdecf UUID := gen_random_uuid();
    v_jur_d5496492_b4f2_5999_21e7_7214cc3fdecf UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope_d5496492_b4f2_5999_21e7_7214cc3fdecf, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope_d5496492_b4f2_5999_21e7_7214cc3fdecf, 'd5496492-b4f2-5999-21e7-7214cc3fdecf');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur_d5496492_b4f2_5999_21e7_7214cc3fdecf, v_country_id, v_scope_d5496492_b4f2_5999_21e7_7214cc3fdecf, 'IN_d5496492', 'Haryana Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_sgst_regime_id, 
      v_jur_d5496492_b4f2_5999_21e7_7214cc3fdecf, 
      'SGST', 
      'State GST - Haryana', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'PROVEN_HASH:71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'ACTIVE'
    );
  END;

  -- Himachal Pradesh
  DECLARE
    v_scope_edbee470_8162_8af7_e00d_e279f44c0efb UUID := gen_random_uuid();
    v_jur_edbee470_8162_8af7_e00d_e279f44c0efb UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope_edbee470_8162_8af7_e00d_e279f44c0efb, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope_edbee470_8162_8af7_e00d_e279f44c0efb, 'edbee470-8162-8af7-e00d-e279f44c0efb');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur_edbee470_8162_8af7_e00d_e279f44c0efb, v_country_id, v_scope_edbee470_8162_8af7_e00d_e279f44c0efb, 'IN_edbee470', 'Himachal Pradesh Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_sgst_regime_id, 
      v_jur_edbee470_8162_8af7_e00d_e279f44c0efb, 
      'SGST', 
      'State GST - Himachal Pradesh', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'PROVEN_HASH:71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'ACTIVE'
    );
  END;

  -- Jammu And Kashmir
  DECLARE
    v_scope_2cfc0a45_1570_da34_53ab_fdef1f5b663f UUID := gen_random_uuid();
    v_jur_2cfc0a45_1570_da34_53ab_fdef1f5b663f UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope_2cfc0a45_1570_da34_53ab_fdef1f5b663f, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope_2cfc0a45_1570_da34_53ab_fdef1f5b663f, '2cfc0a45-1570-da34-53ab-fdef1f5b663f');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur_2cfc0a45_1570_da34_53ab_fdef1f5b663f, v_country_id, v_scope_2cfc0a45_1570_da34_53ab_fdef1f5b663f, 'IN_2cfc0a45', 'Jammu And Kashmir Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_sgst_regime_id, 
      v_jur_2cfc0a45_1570_da34_53ab_fdef1f5b663f, 
      'SGST', 
      'State GST - Jammu And Kashmir', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'PROVEN_HASH:71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'ACTIVE'
    );
  END;

  -- Jharkhand
  DECLARE
    v_scope_25b4c210_24fb_f7cb_a5e3_b6a59dda194a UUID := gen_random_uuid();
    v_jur_25b4c210_24fb_f7cb_a5e3_b6a59dda194a UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope_25b4c210_24fb_f7cb_a5e3_b6a59dda194a, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope_25b4c210_24fb_f7cb_a5e3_b6a59dda194a, '25b4c210-24fb-f7cb-a5e3-b6a59dda194a');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur_25b4c210_24fb_f7cb_a5e3_b6a59dda194a, v_country_id, v_scope_25b4c210_24fb_f7cb_a5e3_b6a59dda194a, 'IN_25b4c210', 'Jharkhand Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_sgst_regime_id, 
      v_jur_25b4c210_24fb_f7cb_a5e3_b6a59dda194a, 
      'SGST', 
      'State GST - Jharkhand', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'PROVEN_HASH:71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'ACTIVE'
    );
  END;

  -- Karnataka
  DECLARE
    v_scope_55b772b6_c146_0c14_1ab3_1a3cf2ada5e1 UUID := gen_random_uuid();
    v_jur_55b772b6_c146_0c14_1ab3_1a3cf2ada5e1 UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope_55b772b6_c146_0c14_1ab3_1a3cf2ada5e1, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope_55b772b6_c146_0c14_1ab3_1a3cf2ada5e1, '55b772b6-c146-0c14-1ab3-1a3cf2ada5e1');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur_55b772b6_c146_0c14_1ab3_1a3cf2ada5e1, v_country_id, v_scope_55b772b6_c146_0c14_1ab3_1a3cf2ada5e1, 'IN_55b772b6', 'Karnataka Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_sgst_regime_id, 
      v_jur_55b772b6_c146_0c14_1ab3_1a3cf2ada5e1, 
      'SGST', 
      'State GST - Karnataka', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'PROVEN_HASH:71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'ACTIVE'
    );
  END;

  -- Kerala
  DECLARE
    v_scope_57f42cb4_5c7b_1858_de78_d6cee9c61a60 UUID := gen_random_uuid();
    v_jur_57f42cb4_5c7b_1858_de78_d6cee9c61a60 UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope_57f42cb4_5c7b_1858_de78_d6cee9c61a60, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope_57f42cb4_5c7b_1858_de78_d6cee9c61a60, '57f42cb4-5c7b-1858-de78-d6cee9c61a60');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur_57f42cb4_5c7b_1858_de78_d6cee9c61a60, v_country_id, v_scope_57f42cb4_5c7b_1858_de78_d6cee9c61a60, 'IN_57f42cb4', 'Kerala Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_sgst_regime_id, 
      v_jur_57f42cb4_5c7b_1858_de78_d6cee9c61a60, 
      'SGST', 
      'State GST - Kerala', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'PROVEN_HASH:71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'ACTIVE'
    );
  END;

  -- Ladakh
  DECLARE
    v_scope_acdece69_411a_a043_d40b_8bf5042d84ac UUID := gen_random_uuid();
    v_jur_acdece69_411a_a043_d40b_8bf5042d84ac UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope_acdece69_411a_a043_d40b_8bf5042d84ac, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope_acdece69_411a_a043_d40b_8bf5042d84ac, 'acdece69-411a-a043-d40b-8bf5042d84ac');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur_acdece69_411a_a043_d40b_8bf5042d84ac, v_country_id, v_scope_acdece69_411a_a043_d40b_8bf5042d84ac, 'IN_acdece69', 'Ladakh Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_utgst_regime_id, 
      v_jur_acdece69_411a_a043_d40b_8bf5042d84ac, 
      'UTGST', 
      'Union Territory GST - Ladakh', 
      'GST', 
      'https://cbic-gst.gov.in', 
      'UNRESOLVED: UTGST_ACT_CURRENT',
      'UNRESOLVED'
    );
  END;

  -- Lakshadweep
  DECLARE
    v_scope_c8503e4c_bd34_ccb2_ff15_a7f2ac7f9430 UUID := gen_random_uuid();
    v_jur_c8503e4c_bd34_ccb2_ff15_a7f2ac7f9430 UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope_c8503e4c_bd34_ccb2_ff15_a7f2ac7f9430, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope_c8503e4c_bd34_ccb2_ff15_a7f2ac7f9430, 'c8503e4c-bd34-ccb2-ff15-a7f2ac7f9430');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur_c8503e4c_bd34_ccb2_ff15_a7f2ac7f9430, v_country_id, v_scope_c8503e4c_bd34_ccb2_ff15_a7f2ac7f9430, 'IN_c8503e4c', 'Lakshadweep Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_utgst_regime_id, 
      v_jur_c8503e4c_bd34_ccb2_ff15_a7f2ac7f9430, 
      'UTGST', 
      'Union Territory GST - Lakshadweep', 
      'GST', 
      'https://cbic-gst.gov.in', 
      'UNRESOLVED: UTGST_ACT_CURRENT',
      'UNRESOLVED'
    );
  END;

  -- Madhya Pradesh
  DECLARE
    v_scope_960251c4_7e6a_f45c_3733_065b7d46c955 UUID := gen_random_uuid();
    v_jur_960251c4_7e6a_f45c_3733_065b7d46c955 UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope_960251c4_7e6a_f45c_3733_065b7d46c955, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope_960251c4_7e6a_f45c_3733_065b7d46c955, '960251c4-7e6a-f45c-3733-065b7d46c955');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur_960251c4_7e6a_f45c_3733_065b7d46c955, v_country_id, v_scope_960251c4_7e6a_f45c_3733_065b7d46c955, 'IN_960251c4', 'Madhya Pradesh Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_sgst_regime_id, 
      v_jur_960251c4_7e6a_f45c_3733_065b7d46c955, 
      'SGST', 
      'State GST - Madhya Pradesh', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'PROVEN_HASH:71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'ACTIVE'
    );
  END;

  -- Maharashtra
  DECLARE
    v_scope_8ee3181b_105e_cdb3_9b6f_9bf350d978ab UUID := gen_random_uuid();
    v_jur_8ee3181b_105e_cdb3_9b6f_9bf350d978ab UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope_8ee3181b_105e_cdb3_9b6f_9bf350d978ab, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope_8ee3181b_105e_cdb3_9b6f_9bf350d978ab, '8ee3181b-105e-cdb3-9b6f-9bf350d978ab');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur_8ee3181b_105e_cdb3_9b6f_9bf350d978ab, v_country_id, v_scope_8ee3181b_105e_cdb3_9b6f_9bf350d978ab, 'IN_8ee3181b', 'Maharashtra Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_sgst_regime_id, 
      v_jur_8ee3181b_105e_cdb3_9b6f_9bf350d978ab, 
      'SGST', 
      'State GST - Maharashtra', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'PROVEN_HASH:71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'ACTIVE'
    );
  END;

  -- Manipur
  DECLARE
    v_scope_37a1c514_2b48_ab29_1f55_0c467da18b2c UUID := gen_random_uuid();
    v_jur_37a1c514_2b48_ab29_1f55_0c467da18b2c UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope_37a1c514_2b48_ab29_1f55_0c467da18b2c, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope_37a1c514_2b48_ab29_1f55_0c467da18b2c, '37a1c514-2b48-ab29-1f55-0c467da18b2c');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur_37a1c514_2b48_ab29_1f55_0c467da18b2c, v_country_id, v_scope_37a1c514_2b48_ab29_1f55_0c467da18b2c, 'IN_37a1c514', 'Manipur Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_sgst_regime_id, 
      v_jur_37a1c514_2b48_ab29_1f55_0c467da18b2c, 
      'SGST', 
      'State GST - Manipur', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'PROVEN_HASH:71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'ACTIVE'
    );
  END;

  -- Meghalaya
  DECLARE
    v_scope_e6fac942_38a5_5204_031e_fc8e40e9e2c8 UUID := gen_random_uuid();
    v_jur_e6fac942_38a5_5204_031e_fc8e40e9e2c8 UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope_e6fac942_38a5_5204_031e_fc8e40e9e2c8, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope_e6fac942_38a5_5204_031e_fc8e40e9e2c8, 'e6fac942-38a5-5204-031e-fc8e40e9e2c8');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur_e6fac942_38a5_5204_031e_fc8e40e9e2c8, v_country_id, v_scope_e6fac942_38a5_5204_031e_fc8e40e9e2c8, 'IN_e6fac942', 'Meghalaya Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_sgst_regime_id, 
      v_jur_e6fac942_38a5_5204_031e_fc8e40e9e2c8, 
      'SGST', 
      'State GST - Meghalaya', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'PROVEN_HASH:71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'ACTIVE'
    );
  END;

  -- Mizoram
  DECLARE
    v_scope_0fe570c4_d3d5_dde0_4d33_b1e3d97ebee2 UUID := gen_random_uuid();
    v_jur_0fe570c4_d3d5_dde0_4d33_b1e3d97ebee2 UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope_0fe570c4_d3d5_dde0_4d33_b1e3d97ebee2, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope_0fe570c4_d3d5_dde0_4d33_b1e3d97ebee2, '0fe570c4-d3d5-dde0-4d33-b1e3d97ebee2');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur_0fe570c4_d3d5_dde0_4d33_b1e3d97ebee2, v_country_id, v_scope_0fe570c4_d3d5_dde0_4d33_b1e3d97ebee2, 'IN_0fe570c4', 'Mizoram Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_sgst_regime_id, 
      v_jur_0fe570c4_d3d5_dde0_4d33_b1e3d97ebee2, 
      'SGST', 
      'State GST - Mizoram', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'PROVEN_HASH:71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'ACTIVE'
    );
  END;

  -- Nagaland
  DECLARE
    v_scope_1eb6d30e_66b0_94c5_83a6_ce8c85b807ac UUID := gen_random_uuid();
    v_jur_1eb6d30e_66b0_94c5_83a6_ce8c85b807ac UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope_1eb6d30e_66b0_94c5_83a6_ce8c85b807ac, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope_1eb6d30e_66b0_94c5_83a6_ce8c85b807ac, '1eb6d30e-66b0-94c5-83a6-ce8c85b807ac');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur_1eb6d30e_66b0_94c5_83a6_ce8c85b807ac, v_country_id, v_scope_1eb6d30e_66b0_94c5_83a6_ce8c85b807ac, 'IN_1eb6d30e', 'Nagaland Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_sgst_regime_id, 
      v_jur_1eb6d30e_66b0_94c5_83a6_ce8c85b807ac, 
      'SGST', 
      'State GST - Nagaland', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'PROVEN_HASH:71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'ACTIVE'
    );
  END;

  -- Odisha
  DECLARE
    v_scope_a4451246_fb5c_7940_2d34_669dbdd5f742 UUID := gen_random_uuid();
    v_jur_a4451246_fb5c_7940_2d34_669dbdd5f742 UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope_a4451246_fb5c_7940_2d34_669dbdd5f742, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope_a4451246_fb5c_7940_2d34_669dbdd5f742, 'a4451246-fb5c-7940-2d34-669dbdd5f742');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur_a4451246_fb5c_7940_2d34_669dbdd5f742, v_country_id, v_scope_a4451246_fb5c_7940_2d34_669dbdd5f742, 'IN_a4451246', 'Odisha Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_sgst_regime_id, 
      v_jur_a4451246_fb5c_7940_2d34_669dbdd5f742, 
      'SGST', 
      'State GST - Odisha', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'PROVEN_HASH:71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'ACTIVE'
    );
  END;

  -- Puducherry
  DECLARE
    v_scope_6451d1c6_a257_09d5_0b53_64a97d641da9 UUID := gen_random_uuid();
    v_jur_6451d1c6_a257_09d5_0b53_64a97d641da9 UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope_6451d1c6_a257_09d5_0b53_64a97d641da9, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope_6451d1c6_a257_09d5_0b53_64a97d641da9, '6451d1c6-a257-09d5-0b53-64a97d641da9');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur_6451d1c6_a257_09d5_0b53_64a97d641da9, v_country_id, v_scope_6451d1c6_a257_09d5_0b53_64a97d641da9, 'IN_6451d1c6', 'Puducherry Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_sgst_regime_id, 
      v_jur_6451d1c6_a257_09d5_0b53_64a97d641da9, 
      'SGST', 
      'State GST - Puducherry', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'PROVEN_HASH:71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'ACTIVE'
    );
  END;

  -- Punjab
  DECLARE
    v_scope_89935061_3bbc_70ec_e190_5af40f567d64 UUID := gen_random_uuid();
    v_jur_89935061_3bbc_70ec_e190_5af40f567d64 UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope_89935061_3bbc_70ec_e190_5af40f567d64, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope_89935061_3bbc_70ec_e190_5af40f567d64, '89935061-3bbc-70ec-e190-5af40f567d64');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur_89935061_3bbc_70ec_e190_5af40f567d64, v_country_id, v_scope_89935061_3bbc_70ec_e190_5af40f567d64, 'IN_89935061', 'Punjab Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_sgst_regime_id, 
      v_jur_89935061_3bbc_70ec_e190_5af40f567d64, 
      'SGST', 
      'State GST - Punjab', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'PROVEN_HASH:71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'ACTIVE'
    );
  END;

  -- Rajasthan
  DECLARE
    v_scope_f94d6d3d_ad66_0195_b2af_7a2826dcb3f0 UUID := gen_random_uuid();
    v_jur_f94d6d3d_ad66_0195_b2af_7a2826dcb3f0 UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope_f94d6d3d_ad66_0195_b2af_7a2826dcb3f0, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope_f94d6d3d_ad66_0195_b2af_7a2826dcb3f0, 'f94d6d3d-ad66-0195-b2af-7a2826dcb3f0');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur_f94d6d3d_ad66_0195_b2af_7a2826dcb3f0, v_country_id, v_scope_f94d6d3d_ad66_0195_b2af_7a2826dcb3f0, 'IN_f94d6d3d', 'Rajasthan Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_sgst_regime_id, 
      v_jur_f94d6d3d_ad66_0195_b2af_7a2826dcb3f0, 
      'SGST', 
      'State GST - Rajasthan', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'PROVEN_HASH:71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'ACTIVE'
    );
  END;

  -- Sikkim
  DECLARE
    v_scope_a9b1575a_55fa_2e40_22b5_92c7ed7ec929 UUID := gen_random_uuid();
    v_jur_a9b1575a_55fa_2e40_22b5_92c7ed7ec929 UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope_a9b1575a_55fa_2e40_22b5_92c7ed7ec929, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope_a9b1575a_55fa_2e40_22b5_92c7ed7ec929, 'a9b1575a-55fa-2e40-22b5-92c7ed7ec929');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur_a9b1575a_55fa_2e40_22b5_92c7ed7ec929, v_country_id, v_scope_a9b1575a_55fa_2e40_22b5_92c7ed7ec929, 'IN_a9b1575a', 'Sikkim Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_sgst_regime_id, 
      v_jur_a9b1575a_55fa_2e40_22b5_92c7ed7ec929, 
      'SGST', 
      'State GST - Sikkim', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'PROVEN_HASH:71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'ACTIVE'
    );
  END;

  -- Tamil Nadu
  DECLARE
    v_scope_edc9ce5b_1209_e0e2_3ada_9c9e43959fcf UUID := gen_random_uuid();
    v_jur_edc9ce5b_1209_e0e2_3ada_9c9e43959fcf UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope_edc9ce5b_1209_e0e2_3ada_9c9e43959fcf, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope_edc9ce5b_1209_e0e2_3ada_9c9e43959fcf, 'edc9ce5b-1209-e0e2-3ada-9c9e43959fcf');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur_edc9ce5b_1209_e0e2_3ada_9c9e43959fcf, v_country_id, v_scope_edc9ce5b_1209_e0e2_3ada_9c9e43959fcf, 'IN_edc9ce5b', 'Tamil Nadu Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_sgst_regime_id, 
      v_jur_edc9ce5b_1209_e0e2_3ada_9c9e43959fcf, 
      'SGST', 
      'State GST - Tamil Nadu', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'PROVEN_HASH:71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'ACTIVE'
    );
  END;

  -- Telangana
  DECLARE
    v_scope_90268fab_d970_a3f4_4c42_d2f7bed6d9cb UUID := gen_random_uuid();
    v_jur_90268fab_d970_a3f4_4c42_d2f7bed6d9cb UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope_90268fab_d970_a3f4_4c42_d2f7bed6d9cb, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope_90268fab_d970_a3f4_4c42_d2f7bed6d9cb, '90268fab-d970-a3f4-4c42-d2f7bed6d9cb');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur_90268fab_d970_a3f4_4c42_d2f7bed6d9cb, v_country_id, v_scope_90268fab_d970_a3f4_4c42_d2f7bed6d9cb, 'IN_90268fab', 'Telangana Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_sgst_regime_id, 
      v_jur_90268fab_d970_a3f4_4c42_d2f7bed6d9cb, 
      'SGST', 
      'State GST - Telangana', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'PROVEN_HASH:71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'ACTIVE'
    );
  END;

  -- The Dadra And Nagar Haveli And Daman And Diu
  DECLARE
    v_scope_efb9258b_37c6_c754_56b6_78a008a85a11 UUID := gen_random_uuid();
    v_jur_efb9258b_37c6_c754_56b6_78a008a85a11 UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope_efb9258b_37c6_c754_56b6_78a008a85a11, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope_efb9258b_37c6_c754_56b6_78a008a85a11, 'efb9258b-37c6-c754-56b6-78a008a85a11');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur_efb9258b_37c6_c754_56b6_78a008a85a11, v_country_id, v_scope_efb9258b_37c6_c754_56b6_78a008a85a11, 'IN_efb9258b', 'The Dadra And Nagar Haveli And Daman And Diu Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_sgst_regime_id, 
      v_jur_efb9258b_37c6_c754_56b6_78a008a85a11, 
      'SGST', 
      'State GST - The Dadra And Nagar Haveli And Daman And Diu', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'PROVEN_HASH:71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'ACTIVE'
    );
  END;

  -- Tripura
  DECLARE
    v_scope_1900638b_5ff4_4eee_c4b3_6ae178e508dd UUID := gen_random_uuid();
    v_jur_1900638b_5ff4_4eee_c4b3_6ae178e508dd UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope_1900638b_5ff4_4eee_c4b3_6ae178e508dd, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope_1900638b_5ff4_4eee_c4b3_6ae178e508dd, '1900638b-5ff4-4eee-c4b3-6ae178e508dd');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur_1900638b_5ff4_4eee_c4b3_6ae178e508dd, v_country_id, v_scope_1900638b_5ff4_4eee_c4b3_6ae178e508dd, 'IN_1900638b', 'Tripura Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_sgst_regime_id, 
      v_jur_1900638b_5ff4_4eee_c4b3_6ae178e508dd, 
      'SGST', 
      'State GST - Tripura', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'PROVEN_HASH:71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'ACTIVE'
    );
  END;

  -- Uttarakhand
  DECLARE
    v_scope_8e4ac819_9c18_b049_a315_0dc284acc070 UUID := gen_random_uuid();
    v_jur_8e4ac819_9c18_b049_a315_0dc284acc070 UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope_8e4ac819_9c18_b049_a315_0dc284acc070, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope_8e4ac819_9c18_b049_a315_0dc284acc070, '8e4ac819-9c18-b049-a315-0dc284acc070');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur_8e4ac819_9c18_b049_a315_0dc284acc070, v_country_id, v_scope_8e4ac819_9c18_b049_a315_0dc284acc070, 'IN_8e4ac819', 'Uttarakhand Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_sgst_regime_id, 
      v_jur_8e4ac819_9c18_b049_a315_0dc284acc070, 
      'SGST', 
      'State GST - Uttarakhand', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'PROVEN_HASH:71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'ACTIVE'
    );
  END;

  -- Uttar Pradesh
  DECLARE
    v_scope_94191f37_522d_6ead_2c40_cbe065041941 UUID := gen_random_uuid();
    v_jur_94191f37_522d_6ead_2c40_cbe065041941 UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope_94191f37_522d_6ead_2c40_cbe065041941, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope_94191f37_522d_6ead_2c40_cbe065041941, '94191f37-522d-6ead-2c40-cbe065041941');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur_94191f37_522d_6ead_2c40_cbe065041941, v_country_id, v_scope_94191f37_522d_6ead_2c40_cbe065041941, 'IN_94191f37', 'Uttar Pradesh Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_sgst_regime_id, 
      v_jur_94191f37_522d_6ead_2c40_cbe065041941, 
      'SGST', 
      'State GST - Uttar Pradesh', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'PROVEN_HASH:71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'ACTIVE'
    );
  END;

  -- West Bengal
  DECLARE
    v_scope_89dcba4a_145b_6fe0_d34e_d94250e0dbf1 UUID := gen_random_uuid();
    v_jur_89dcba4a_145b_6fe0_d34e_d94250e0dbf1 UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope_89dcba4a_145b_6fe0_d34e_d94250e0dbf1, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope_89dcba4a_145b_6fe0_d34e_d94250e0dbf1, '89dcba4a-145b-6fe0-d34e-d94250e0dbf1');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur_89dcba4a_145b_6fe0_d34e_d94250e0dbf1, v_country_id, v_scope_89dcba4a_145b_6fe0_d34e_d94250e0dbf1, 'IN_89dcba4a', 'West Bengal Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_sgst_regime_id, 
      v_jur_89dcba4a_145b_6fe0_d34e_d94250e0dbf1, 
      'SGST', 
      'State GST - West Bengal', 
      'GST', 
      'https://www.gstcouncil.gov.in/sgst-act', 
      'PROVEN_HASH:71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
      'ACTIVE'
    );
  END;

  RAISE EXCEPTION 'UNCONDITIONAL_ROLLBACK_REHEARSAL_SUCCESS';
END $$;
ROLLBACK;
