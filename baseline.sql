SELECT
  (SELECT count(*) FROM catalog.hsn_sac WHERE code_type = 'HSN') as hsn_top,
  (SELECT count(*) FROM catalog.hsn_sac WHERE code_type = 'SAC') as sac_top,
  (SELECT count(*) FROM catalog.hsn_sac) as total_hsn_sac,
  (SELECT count(*) FROM catalog.gst_rate_master) as gst_total,
  (SELECT count(*) FROM catalog.gst_rate_master WHERE is_current = true) as gst_current;
