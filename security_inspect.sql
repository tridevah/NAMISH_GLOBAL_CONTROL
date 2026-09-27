-- Security inspection: current_user, session_user, bypass RLS, table owner, RLS state, policies, grants
SELECT current_user, session_user;

SELECT
  r.rolname,
  r.rolbypassrls,
  r.rolsuper,
  r.rolcanlogin
FROM pg_roles r
WHERE r.rolname IN ('postgres', 'supabase_admin', 'authenticator', 'anon', 'authenticated', 'service_role')
ORDER BY r.rolname;

SELECT
  c.relname AS table_name,
  c.relrowsecurity AS rls_enabled,
  c.relforcerowsecurity AS force_rls,
  pg_get_userbyid(c.relowner) AS table_owner
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'catalog' AND c.relname = 'hsn_sac';

SELECT policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'catalog' AND tablename = 'hsn_sac';

SELECT grantee, privilege_type, is_grantable
FROM information_schema.role_table_grants
WHERE table_schema = 'catalog' AND table_name = 'hsn_sac'
ORDER BY grantee, privilege_type;

SELECT v.viewname, v.definition
FROM pg_views v
WHERE v.schemaname = 'public' AND v.viewname = 'hsn_sac';

SELECT c.relname, c.reloptions
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relname = 'hsn_sac';
