SELECT 
    version,
    name,
    array_length(statements, 1) as statement_count,
    CASE WHEN array_to_string(statements, ' ') LIKE '%INSERT INTO catalog.geography_units%' THEN true ELSE false END as contains_dml
FROM supabase_migrations.schema_migrations
WHERE version >= '20260901000002' AND version <= '20260901000006'
ORDER BY version ASC;
