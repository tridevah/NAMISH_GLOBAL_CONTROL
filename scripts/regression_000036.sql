BEGIN TRANSACTION READ ONLY;
-- R16 status (correct columns)
SELECT id, release_name, status, finalized_at FROM data_imports.releases WHERE id = '5fac63d7-0101-43c5-8867-bd75ff609861';
-- Functional regression
SELECT jsonb_array_length((public.rpc_get_units('cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d'::uuid, NULL, NULL, NULL, NULL, 5, 0))->'rows') as p_len, (public.rpc_get_units('cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d'::uuid, NULL, NULL, NULL, NULL, 5, 0))->'total' as p_tot;
SELECT jsonb_array_length((public.rpc_get_units('cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d'::uuid, NULL, NULL, NULL, NULL, 200, 0))->'rows') as p_len, (public.rpc_get_units('cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d'::uuid, NULL, NULL, NULL, NULL, 200, 0))->'total' as p_tot;
SELECT jsonb_array_length((public.rpc_get_units('cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d'::uuid, NULL, NULL, NULL, NULL, 200, 200))->'rows') as p_len, (public.rpc_get_units('cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d'::uuid, NULL, NULL, NULL, NULL, 200, 200))->'total' as p_tot;
SELECT jsonb_array_length((public.rpc_get_units('cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d'::uuid, NULL, NULL, NULL, NULL, 200, 7800))->'rows') as p_len, (public.rpc_get_units('cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d'::uuid, NULL, NULL, NULL, NULL, 200, 7800))->'total' as p_tot;
SELECT (public.rpc_get_units('cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d'::uuid, 'cc17368a-61a6-b027-c85e-fadeedfe0da8'::uuid, NULL, NULL, NULL, 200, 0))->'total' as state_tot;
SELECT (public.rpc_get_units('cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d'::uuid, '1b6e5e2a-db7c-d9ee-073e-dbb807ed0caf'::uuid, NULL, NULL, NULL, 200, 0))->'total' as dist_tot;
SELECT jsonb_array_length((public.rpc_get_units('cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d'::uuid, '1b6e5e2a-db7c-d9ee-073e-dbb807ed0caf'::uuid, NULL, NULL, NULL, 200, 600))->'rows') as dist_final;
SELECT (public.rpc_get_units('cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d'::uuid, 'd8f00de9-7051-bc5a-3229-35c171d3198f'::uuid, NULL, NULL, NULL, 200, 0))->'total' as subdist_tot;
SELECT jsonb_array_length((public.rpc_get_units('cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d'::uuid, 'd8f00de9-7051-bc5a-3229-35c171d3198f'::uuid, NULL, NULL, NULL, 200, 7000))->'rows') as subdist_final;
-- LOCALITY level id check
SELECT (public.rpc_get_units('cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d'::uuid, '0f65afaa-7700-14e4-75eb-7fbf2389d0b6'::uuid, NULL, NULL, NULL, 200, 0))->'total' as locality_tot;
-- Empty search
SELECT jsonb_array_length((public.rpc_get_units('cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d'::uuid, NULL, NULL, NULL, 'ZZZIMPOSSIBLE999', 200, 0))->'rows') as empty_rows, (public.rpc_get_units('cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d'::uuid, NULL, NULL, NULL, 'ZZZIMPOSSIBLE999', 200, 0))->'total' as empty_tot;
-- Adjacent page duplicate check: get IDs from page 1 and page 2, intersect
SELECT COUNT(*) AS page1_count FROM jsonb_array_elements((public.rpc_get_units('cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d'::uuid, NULL, NULL, NULL, NULL, 200, 0))->'rows') r;
ROLLBACK;
