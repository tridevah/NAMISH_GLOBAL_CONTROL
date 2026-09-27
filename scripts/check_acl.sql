BEGIN TRANSACTION READ ONLY;
SELECT proacl FROM pg_proc WHERE proname = 'rpc_get_units';
ROLLBACK;
