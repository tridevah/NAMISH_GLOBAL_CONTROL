SELECT jsonb_array_length((public.rpc_get_units('cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d'::uuid, NULL, NULL, NULL, 'IMPOSSIBLE_SEARCH_STRING_12345', 200, 0))->'rows') as empty_len,
       (public.rpc_get_units('cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d'::uuid, NULL, NULL, NULL, 'IMPOSSIBLE_SEARCH_STRING_12345', 200, 0))->'total' as empty_tot;
SELECT (public.rpc_get_units('cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d'::uuid, '0f65afaa-7700-14e4-75eb-7fbf2389d0b6'::uuid, NULL, NULL, NULL, 200, 0))->'total' as village_tot;
