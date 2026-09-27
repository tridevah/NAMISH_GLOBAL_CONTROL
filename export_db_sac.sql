-- Export all SAC DB tuples for set comparison
SELECT
  id,
  code_type,
  code,
  description,
  parent_code,
  classification_level,
  status,
  official_source,
  source_reference
FROM catalog.hsn_sac
WHERE code_type = 'SAC'
ORDER BY code;
