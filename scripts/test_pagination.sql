BEGIN TRANSACTION READ ONLY;
SELECT jsonb_array_length((public.rpc_get_units('cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d'::uuid, NULL, NULL, NULL, NULL, 5, 0))->'rows') as r_len,
       (public.rpc_get_units('cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d'::uuid, NULL, NULL, NULL, NULL, 5, 0))->'total' as r_tot;

SELECT jsonb_array_length((public.rpc_get_units('cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d'::uuid, NULL, NULL, NULL, NULL, 200, 0))->'rows') as r_len,
       (public.rpc_get_units('cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d'::uuid, NULL, NULL, NULL, NULL, 200, 0))->'total' as r_tot;

SELECT jsonb_array_length((public.rpc_get_units('cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d'::uuid, NULL, NULL, NULL, NULL, 200, 200))->'rows') as r_len,
       (public.rpc_get_units('cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d'::uuid, NULL, NULL, NULL, NULL, 200, 200))->'total' as r_tot;

SELECT jsonb_array_length((public.rpc_get_units('cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d'::uuid, NULL, NULL, NULL, NULL, 200, 8400))->'rows') as r_len,
       (public.rpc_get_units('cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d'::uuid, NULL, NULL, NULL, NULL, 200, 8400))->'total' as r_tot;

SELECT (public.rpc_get_units('cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d'::uuid, 'cc17368a-61a6-b027-c85e-fadeedfe0da8'::uuid, NULL, NULL, NULL, 200, 0))->'total' as state_tot;
SELECT (public.rpc_get_units('cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d'::uuid, '1b6e5e2a-db7c-d9ee-073e-dbb807ed0caf'::uuid, NULL, NULL, NULL, 200, 0))->'total' as dist_tot;
SELECT (public.rpc_get_units('cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d'::uuid, 'd8f00de9-7051-bc5a-3229-35c171d3198f'::uuid, NULL, NULL, NULL, 200, 0))->'total' as subdist_tot;

ROLLBACK;
