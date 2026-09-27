BEGIN TRANSACTION READ ONLY;
SELECT column_name, data_type FROM information_schema.columns WHERE table_schema = 'supabase_migrations' AND table_name = 'schema_migrations';
SELECT * FROM supabase_migrations.schema_migrations WHERE version IN ('20260830000035', '20260830000036') ORDER BY version;
ROLLBACK;
