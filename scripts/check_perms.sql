BEGIN TRANSACTION READ ONLY;
SELECT has_function_privilege('anon', 'public.rpc_get_units(uuid, uuid, uuid, text, text, integer, integer)', 'EXECUTE');
SELECT has_function_privilege('authenticated', 'public.rpc_get_units(uuid, uuid, uuid, text, text, integer, integer)', 'EXECUTE');
SELECT has_function_privilege('service_role', 'public.rpc_get_units(uuid, uuid, uuid, text, text, integer, integer)', 'EXECUTE');
ROLLBACK;
