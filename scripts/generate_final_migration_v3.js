const fs = require('fs');

const states = JSON.parse(fs.readFileSync('india_states_clean.json', 'utf8'));
const uts = ['Andaman And Nicobar Islands', 'Chandigarh', 'Dadra And Nagar Haveli And Daman And Diu', 'Ladakh', 'Lakshadweep'];

let sql = `-- Migration: India Canonical Business Tax System Rehearsal
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

DO $$
DECLARE
  v_country_id UUID;
  v_sgst_regime_id UUID := gen_random_uuid();
  v_utgst_regime_id UUID := gen_random_uuid();
  v_cgst_regime_id UUID := gen_random_uuid();
  v_igst_regime_id UUID := gen_random_uuid();
  v_cess_regime_id UUID := gen_random_uuid();
  
  v_scopes INT;
  v_jurs INT;
  v_comps INT;
BEGIN
  SELECT id INTO v_country_id FROM catalog.countries WHERE iso2 = 'IN';

  -- CGST
  INSERT INTO catalog.tax_regimes (id, country_id, code, name, official_website, provenance_reference, status)
  VALUES (v_cgst_regime_id, v_country_id, 'CGST', 'Central GST', 'https://www.indiacode.nic.in', 'UNRESOLVED: CGST_ACT', 'UNRESOLVED');

  -- IGST
  INSERT INTO catalog.tax_regimes (id, country_id, code, name, official_website, provenance_reference, status)
  VALUES (v_igst_regime_id, v_country_id, 'IGST', 'Integrated GST', 'https://www.indiacode.nic.in', 'UNRESOLVED: IGST_ACT', 'UNRESOLVED');

  -- SGST
  INSERT INTO catalog.tax_regimes (id, country_id, code, name, official_website, provenance_reference, status)
  VALUES (v_sgst_regime_id, v_country_id, 'SGST', 'State GST', 'https://www.gstcouncil.gov.in/sgst-act', 'OFFICIAL_INDEX_PROVEN: HASH_71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42', 'UNRESOLVED');

  -- UTGST
  INSERT INTO catalog.tax_regimes (id, country_id, code, name, official_website, provenance_reference, status)
  VALUES (v_utgst_regime_id, v_country_id, 'UTGST', 'Union Territory GST', 'https://www.indiacode.nic.in', 'UNRESOLVED: UTGST_ACT', 'UNRESOLVED');

  -- CESS
  INSERT INTO catalog.tax_regimes (id, country_id, code, name, official_website, provenance_reference, status)
  VALUES (v_cess_regime_id, v_country_id, 'COMPENSATION_CESS', 'GST Compensation Cess', 'https://www.indiacode.nic.in', 'UNRESOLVED: GST_COMPENSATION_CESS_ACT', 'UNRESOLVED');

`;

for (const st of states) {
    const isUt = uts.includes(st.official_name);
    
    sql += `
  -- ${st.official_name}
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, '${st.id}');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_${st.id.split('-')[0]}', '${st.official_name.replace(/'/g, "''")} Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      ${isUt ? 'v_utgst_regime_id' : 'v_sgst_regime_id'}, 
      v_jur, 
      '${isUt ? 'UTGST' : 'SGST'}', 
      '${isUt ? 'Union Territory GST' : 'State GST'} - ${st.official_name.replace(/'/g, "''")}', 
      'GST', 
      '${isUt ? 'https://cbic-gst.gov.in' : 'https://www.gstcouncil.gov.in/sgst-act'}', 
      '${isUt ? 'UNRESOLVED: UTGST_ACT' : 'OFFICIAL_INDEX_PROVEN: HASH_71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42'}',
      'UNRESOLVED'
    );
  END;
`;
}

sql += `
  -- Verify counts
  SELECT COUNT(*) INTO v_scopes FROM catalog.scope_geographies;
  SELECT COUNT(*) INTO v_jurs FROM catalog.jurisdictions WHERE code LIKE 'IN_%';
  SELECT COUNT(*) INTO v_comps FROM catalog.tax_components;
  
  RAISE NOTICE 'Scope Geographies: %', v_scopes;
  RAISE NOTICE 'India Jurisdictions mapped: %', v_jurs;
  RAISE NOTICE 'Tax Components mapped: %', v_comps;
  
  RAISE EXCEPTION 'UNCONDITIONAL_ROLLBACK_REHEARSAL_SUCCESS';
END $$;
`;

fs.writeFileSync('rehearsal_workdir/supabase/migrations/20260903000003_india_tax_system_rehearsal_v3.sql', sql);
console.log('Migration v3 generated.');
