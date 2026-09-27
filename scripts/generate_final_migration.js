const fs = require('fs');

const manifest = JSON.parse(fs.readFileSync('gst_sources/source_manifest_v3_2.json', 'utf8')).manifest;
const states = JSON.parse(fs.readFileSync('india_states_clean.json', 'utf8'));

// 31 SGST jurisdictions are proven. The 5 UTGST ones are unresolved.
// We'll separate states from UTs manually or based on a known list.
const uts = ['Andaman And Nicobar Islands', 'Chandigarh', 'Dadra And Nagar Haveli And Daman And Diu', 'Ladakh', 'Lakshadweep'];

let sql = `-- Migration: India Canonical Business Tax System (Verified & Unresolved)
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

`;

for (const st of states) {
    const isUt = uts.includes(st.official_name);
    const scopeId = `gen_random_uuid()`;
    const jurId = `gen_random_uuid()`;
    
    sql += `
  -- ${st.official_name}
  DECLARE
    v_scope_${st.id.replace(/-/g, '_')} UUID := ${scopeId};
    v_jur_${st.id.replace(/-/g, '_')} UUID := ${jurId};
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope_${st.id.replace(/-/g, '_')}, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope_${st.id.replace(/-/g, '_')}, '${st.id}');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur_${st.id.replace(/-/g, '_')}, v_country_id, v_scope_${st.id.replace(/-/g, '_')}, 'IN_${st.id.split('-')[0]}', '${st.official_name.replace(/'/g, "''")} Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      ${isUt ? 'v_utgst_regime_id' : 'v_sgst_regime_id'}, 
      v_jur_${st.id.replace(/-/g, '_')}, 
      '${isUt ? 'UTGST' : 'SGST'}', 
      '${isUt ? 'Union Territory GST' : 'State GST'} - ${st.official_name.replace(/'/g, "''")}', 
      'GST', 
      '${isUt ? 'https://cbic-gst.gov.in' : 'https://www.gstcouncil.gov.in/sgst-act'}', 
      '${isUt ? 'UNRESOLVED: UTGST_ACT_CURRENT' : 'PROVEN_HASH:71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42'}',
      '${isUt ? 'UNRESOLVED' : 'ACTIVE'}'
    );
  END;
`;
}

sql += `
  RAISE EXCEPTION 'UNCONDITIONAL_ROLLBACK_REHEARSAL_SUCCESS';
END $$;
ROLLBACK;
`;

fs.writeFileSync('supabase/migrations/20260903000001_india_tax_system_verified.sql', sql);
console.log('Migration generated.');
