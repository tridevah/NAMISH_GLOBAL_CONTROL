SELECT version, name, array_length(statements, 1) as stmt_count,
  CASE WHEN array_to_string(statements,' ') LIKE '%INSERT INTO catalog.geography_units%' THEN 'YES' ELSE 'NO' END as has_canonical_dml,
  CASE WHEN array_to_string(statements,' ') LIKE '%IF c_state = 36 AND c_dist = 784%' THEN 'YES' ELSE 'NO' END as has_promoted_branch,
  CASE WHEN array_to_string(statements,' ') LIKE '%IF c_state = 36 AND c_dist = 0%' THEN 'YES' ELSE 'NO' END as has_clean_branch
FROM supabase_migrations.schema_migrations
WHERE version >= '20260901000002' AND version <= '20260901000007'
ORDER BY version;
