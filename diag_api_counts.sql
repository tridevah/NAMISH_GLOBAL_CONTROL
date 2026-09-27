SELECT 
  (SELECT count(*) FROM catalog.hsn_sac WHERE country_id = (SELECT id FROM catalog.countries WHERE iso2 = 'IN') AND status IN ('ACTIVE', 'TOP_LEVEL_CLASSIFICATION_ONLY')) as india_count,
  (SELECT count(*) FROM catalog.hsn_sac WHERE country_id = (SELECT id FROM catalog.countries WHERE iso2 = 'US') AND status IN ('ACTIVE', 'TOP_LEVEL_CLASSIFICATION_ONLY')) as us_count;
