SELECT
  (SELECT count(*) FROM catalog.hsn_sac WHERE code_type = 'HSN') as hsn_count,
  (SELECT count(*) FROM catalog.hsn_sac WHERE code_type = 'SAC') as sac_count,
  (SELECT count(*) FROM catalog.hsn_sac) as total_hsn_sac,
  (SELECT count(*) FROM catalog.hsn_sac WHERE status = 'TOP_LEVEL_CLASSIFICATION_ONLY') as top_level_count,
  (SELECT count(*) FROM catalog.hsn_sac WHERE status = 'ACTIVE') as active_count,
  (SELECT count(*) FROM catalog.countries) as countries,
  (SELECT count(*) FROM catalog.currencies) as currencies,
  (SELECT count(*) FROM catalog.gst_rate_master) as gst_total,
  (SELECT count(*) FROM catalog.gst_rate_master WHERE is_current = true) as gst_current;
