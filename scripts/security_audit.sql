BEGIN TRANSACTION READ ONLY;
-- 1, 2, 3, 4
SELECT pg_get_userbyid(proowner) AS owner, prosecdef, proconfig, proacl
FROM pg_proc WHERE proname = 'rpc_get_units';
-- 5, 6, 7
SELECT nspname, nspacl FROM pg_namespace WHERE nspname IN ('public', 'catalog');
-- 8
SELECT datname, datacl FROM pg_database WHERE datname = current_database();
-- 9
SELECT r.rolname, r.rolsuper, array_agg(m.rolname) as member_of
FROM pg_roles r LEFT JOIN pg_auth_members am ON r.oid = am.member LEFT JOIN pg_roles m ON am.roleid = m.oid
WHERE r.rolsuper = false GROUP BY r.rolname;
ROLLBACK;
