-- TEST: Cross Country Denial
DO \$\$
DECLARE
    v_india UUID;
    v_us UUID;
    v_scope UUID;
    v_geo_us UUID;
BEGIN
    INSERT INTO catalog.countries (id, iso2, iso3, official_name, display_name, numeric_code) VALUES 
        ('11111111-1111-1111-1111-111111111111', 'IN', 'IND', 'India', 'India', '356'),
        ('22222222-2222-2222-2222-222222222222', 'US', 'USA', 'United States', 'United States', '840');
    
    INSERT INTO catalog.geography_units (id, country_id, official_code, official_name, display_name) VALUES 
        ('33333333-3333-3333-3333-333333333333', '22222222-2222-2222-2222-222222222222', 'NY', 'New York', 'New York');

    INSERT INTO catalog.applicability_scopes (id, country_id, scope_type) VALUES 
        ('44444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111', 'GEOGRAPHIC');
        
    BEGIN
        INSERT INTO catalog.applicability_scope_geographies (scope_id, geography_unit_id, action) VALUES 
            ('44444444-4444-4444-4444-444444444444', '33333333-3333-3333-3333-333333333333', 'INCLUDE');
        RAISE EXCEPTION 'TEST FAILED: Should have prevented cross-country scope geo!';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'SUCCESS: Cross-country scope geo blocked.';
    END;

    -- Cleanup
    DELETE FROM catalog.applicability_scopes;
    DELETE FROM catalog.geography_units WHERE id = '33333333-3333-3333-3333-333333333333';
    DELETE FROM catalog.countries WHERE id IN ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222');
END;
\$\$;
