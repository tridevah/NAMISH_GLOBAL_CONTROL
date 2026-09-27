UPDATE catalog.country_tax_coverage SET status = 'VERIFIED', reason = NULL WHERE country_id = (SELECT id FROM catalog.countries WHERE iso2 = 'IN');
