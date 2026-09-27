BEGIN TRANSACTION READ ONLY;
-- RLS state
SELECT relname, relrowsecurity, relforcerowsecurity FROM pg_class WHERE relname = 'geography_units';
-- Relevant RLS policies
SELECT polname, polcmd, polpermissive, polroles FROM pg_policy WHERE polrelid = 'catalog.geography_units'::regclass;
-- Role attributes
SELECT rolname, rolsuper, rolinherit, rolcreaterole, rolcreatedb, rolcanlogin, rolbypassrls FROM pg_roles WHERE rolname IN ('postgres', 'service_role', 'anon', 'authenticated');
-- Migration history
SELECT * FROM supabase_migrations.schema_migrations WHERE version LIKE '2026%' ORDER BY version;
ROLLBACK;
