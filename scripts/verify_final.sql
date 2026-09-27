SELECT encode(digest(pg_get_functiondef(p.oid), 'sha256'), 'hex') AS sha256_after, p.proconfig AS search_path, p.proacl
FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'rpc_get_units' AND n.nspname = 'public';
SELECT has_function_privilege('anon', 'public.rpc_get_units(uuid, uuid, uuid, text, text, integer, integer)', 'EXECUTE') AS anon_exec;
SELECT has_function_privilege('authenticated', 'public.rpc_get_units(uuid, uuid, uuid, text, text, integer, integer)', 'EXECUTE') AS auth_exec;
SELECT has_function_privilege('service_role', 'public.rpc_get_units(uuid, uuid, uuid, text, text, integer, integer)', 'EXECUTE') AS svc_exec;
SELECT version FROM supabase_migrations.schema_migrations WHERE version IN ('20260830000035','20260830000036') ORDER BY version;
