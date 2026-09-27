SELECT has_function_privilege('anon', 'public.rpc_get_units(uuid, uuid, uuid, text, text, integer, integer)', 'EXECUTE') AS anon_exec;
SELECT has_function_privilege('authenticated', 'public.rpc_get_units(uuid, uuid, uuid, text, text, integer, integer)', 'EXECUTE') AS auth_exec;
SELECT has_function_privilege('service_role', 'public.rpc_get_units(uuid, uuid, uuid, text, text, integer, integer)', 'EXECUTE') AS service_exec;
