BEGIN TRANSACTION READ ONLY;
SELECT 
    n.nspname AS schema_name,
    p.proname AS function_name,
    pg_get_function_identity_arguments(p.oid) AS identity_args,
    p.oid AS function_oid,
    pg_get_userbyid(p.proowner) AS owner,
    CASE WHEN p.prosecdef THEN 'DEFINER' ELSE 'INVOKER' END AS security_state,
    pg_catalog.pg_get_function_result(p.oid) AS return_type,
    l.lanname AS language,
    CASE p.provolatile WHEN 'i' THEN 'IMMUTABLE' WHEN 's' THEN 'STABLE' WHEN 'v' THEN 'VOLATILE' END AS volatility,
    CASE p.proparallel WHEN 's' THEN 'SAFE' WHEN 'r' THEN 'RESTRICTED' WHEN 'u' THEN 'UNSAFE' END AS parallel_safety,
    p.proconfig AS search_path,
    p.proacl AS acl_grants,
    pg_get_functiondef(p.oid) AS function_def,
    encode(digest(pg_get_functiondef(p.oid), 'sha256'), 'hex') AS def_sha256
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
JOIN pg_language l ON p.prolang = l.oid
WHERE p.proname = 'rpc_get_units' AND n.nspname = 'public';
ROLLBACK;
