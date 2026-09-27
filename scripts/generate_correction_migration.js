const fs = require('fs');

const states = JSON.parse(fs.readFileSync('india_states_clean.json', 'utf8'));

let sql = `-- Migration: India Canonical Business Tax System Rehearsal (Correction)
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

`;

for (const st of states) {
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
  END;
`;
}

sql += `
  -- Verify counts
  SELECT COUNT(*) INTO v_scopes FROM catalog.scope_geographies;
  SELECT COUNT(*) INTO v_jurs FROM catalog.jurisdictions WHERE code LIKE 'IN_%' AND code != 'IN_000000';
  
  RAISE NOTICE 'Scope Geographies mapped: %', v_scopes;
  RAISE NOTICE 'India Sub-Jurisdictions mapped: %', v_jurs;
  
  RAISE EXCEPTION 'UNCONDITIONAL_ROLLBACK_REHEARSAL_SUCCESS';
END $$;
`;

fs.writeFileSync('rehearsal_workdir/supabase/migrations/20260904000002_india_gst_rehearsal_correction.sql', sql);
console.log('Correction Migration generated.');
