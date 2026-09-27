BEGIN TRANSACTION READ ONLY;

-- Post-000036 RPC metadata
SELECT pg_get_userbyid(proowner) AS owner, prosecdef, proconfig AS search_path, proacl AS grants,
       encode(digest(pg_get_functiondef(oid), 'sha256'), 'hex') AS sha256_after
FROM pg_proc WHERE proname = 'rpc_get_units';

-- Migration ledger: 000035 and 000036 both present
SELECT version FROM supabase_migrations.schema_migrations WHERE version IN ('20260830000035', '20260830000036') ORDER BY version;

-- Privilege checks
SELECT has_function_privilege('anon', 'public.rpc_get_units(uuid, uuid, uuid, text, text, integer, integer)', 'EXECUTE') AS anon_exec;
SELECT has_function_privilege('authenticated', 'public.rpc_get_units(uuid, uuid, uuid, text, text, integer, integer)', 'EXECUTE') AS auth_exec;
SELECT has_function_privilege('service_role', 'public.rpc_get_units(uuid, uuid, uuid, text, text, integer, integer)', 'EXECUTE') AS svc_exec;

-- Geography counts
SELECT gl.level_key, COUNT(*) FROM catalog.geography_units u JOIN catalog.geography_levels gl ON gl.id = u.geography_level_id GROUP BY gl.level_key;
SELECT COUNT(*) FROM catalog.development_blocks;
SELECT COUNT(*) FROM catalog.block_districts;

-- R16 status
SELECT id, name, status FROM data_imports.releases WHERE id = '5fac63d7-0101-43c5-8867-bd75ff609861';

ROLLBACK;
