const fs = require('fs');

const states = JSON.parse(fs.readFileSync('india_states_clean.json', 'utf8'));
const uts = ['Andaman And Nicobar Islands', 'Chandigarh', 'Dadra And Nagar Haveli And Daman And Diu', 'Ladakh', 'Lakshadweep'];

let sql = `-- Migration: India Canonical Business Tax System Rehearsal (Phase 1)
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

`;

for (const st of states) {
    const isUt = uts.includes(st.official_name);
    
    sql += `
  -- ${st.official_name}
  DECLARE
    v_scope UUID := gen_random_uuid();
    v_jur UUID := gen_random_uuid();
    v_st_comp UUID := gen_random_uuid();
  BEGIN
    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES (v_scope, v_country_id, 'GEOGRAPHIC');
    INSERT INTO catalog.scope_geographies (applicability_scope_id, geography_unit_id) VALUES (v_scope, '${st.id}');
    INSERT INTO catalog.jurisdictions (id, country_id, applicability_scope_id, code, name) 
    VALUES (v_jur, v_country_id, v_scope, 'IN_${st.id.split('-')[0]}', '${st.official_name.replace(/'/g, "''")} Tax Jurisdiction');
    
    INSERT INTO catalog.tax_components (id, regime_id, jurisdiction_id, code, name, tax_type, official_website, provenance_reference, status)
    VALUES (
      v_st_comp,
      ${isUt ? 'v_utgst_regime_id' : 'v_sgst_regime_id'}, 
      v_jur, 
      '${isUt ? 'UTGST' : 'SGST'}', 
      '${isUt ? 'Union Territory GST' : 'State GST'} - ${st.official_name.replace(/'/g, "''")}', 
      'GST', 
      '${isUt ? 'https://cbic-gst.gov.in' : 'https://www.gstcouncil.gov.in/sgst-act'}', 
      '${isUt ? 'UNRESOLVED: UTGST_ACT' : 'OFFICIAL_INDEX_PROVEN: HASH_71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42'}',
      'UNRESOLVED'
    );

    -- Base Unresolved Rates for SGST/UTGST
    INSERT INTO catalog.tax_rates (component_id, code, rate_percent, is_active, effective_from, provenance_reference, status)
    VALUES 
      (v_st_comp, '${isUt ? 'UTGST' : 'SGST'}_9', 9.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED'),
      (v_st_comp, '${isUt ? 'UTGST' : 'SGST'}_14', 14.00, true, '2017-07-01', 'UNRESOLVED: STATE_RATE_NOTIF', 'UNRESOLVED');
  END;
`;
}

sql += `
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
`;

fs.writeFileSync('rehearsal_workdir/supabase/migrations/20260904000001_india_gst_phase1.sql', sql);
console.log('Phase 1 Migration generated.');
