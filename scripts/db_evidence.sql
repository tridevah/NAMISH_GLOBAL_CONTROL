BEGIN TRANSACTION READ ONLY;
SHOW transaction_read_only;

SELECT * FROM supabase_migrations.schema_migrations WHERE version IN ('20260830000035', '20260830000036') ORDER BY version;

SELECT pg_get_functiondef(oid) FROM pg_proc WHERE proname = 'rpc_get_units';

SELECT pg_get_userbyid(proowner) AS owner, prosecdef, proconfig AS search_path, proacl, encode(digest(pg_get_functiondef(oid), 'sha256'), 'hex') AS sha256 
FROM pg_proc WHERE proname = 'rpc_get_units';

SELECT gl.level_key, COUNT(*) FROM catalog.geography_units u JOIN catalog.geography_levels gl ON gl.id = u.geography_level_id GROUP BY gl.level_key;

SELECT COUNT(*) FROM catalog.development_blocks;

SELECT COUNT(*) FROM catalog.block_districts;

SELECT id, release_name, status FROM data_imports.releases WHERE id = '5fac63d7-0101-43c5-8867-bd75ff609861';

ROLLBACK;
