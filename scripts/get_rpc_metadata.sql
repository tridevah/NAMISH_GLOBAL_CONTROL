SELECT 
    pg_get_userbyid(p.proowner) AS owner,
    p.prosecdef AS secdef,
    p.proconfig AS search_path,
    p.proacl AS grants
FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid 
WHERE p.proname = 'rpc_get_units' AND n.nspname = 'public';
