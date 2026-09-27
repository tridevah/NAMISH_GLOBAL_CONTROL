const fs = require('fs');
const sql = fs.readFileSync('supabase/migrations/20260902000004_tax_authority_data.sql', 'utf8');
const checks = `
-- Verify country coverage
DO $$
DECLARE
    v_total_countries INT;
    v_covered_countries INT;
    v_duplicates INT;
BEGIN
    SELECT COUNT(*) INTO v_total_countries FROM catalog.countries;
    SELECT COUNT(DISTINCT country_id) INTO v_covered_countries FROM catalog.tax_authorities;
    
    RAISE NOTICE 'Total countries: %', v_total_countries;
    RAISE NOTICE 'Covered countries: %', v_covered_countries;
    
    IF v_total_countries != v_covered_countries THEN
        RAISE EXCEPTION 'Country coverage mismatch: Expected %, got %', v_total_countries, v_covered_countries;
    END IF;

    SELECT COUNT(*) INTO v_duplicates
    FROM (
        SELECT country_id, tax_type, COUNT(*) 
        FROM catalog.tax_authorities 
        GROUP BY country_id, tax_type 
        HAVING COUNT(*) > 1
    ) dupes;
    
    RAISE NOTICE 'Exact duplicates found: %', v_duplicates;
END $$;
`;

fs.writeFileSync('scripts/rehearsal.sql', 'BEGIN ISOLATION LEVEL SERIALIZABLE;\n\n' + sql + '\n\n' + checks + '\n\nROLLBACK;\n');
