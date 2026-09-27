SELECT encode(digest(pg_get_functiondef(p.oid), 'sha256'), 'hex') AS def_sha256 
FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid 
WHERE p.proname = 'rpc_get_units' AND n.nspname = 'public';
