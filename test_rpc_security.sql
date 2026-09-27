-- TEST 1: Anon User
SET ROLE anon;
DO \$\$
BEGIN
    PERFORM catalog.rpc_resolve_currency_by_geography('00000000-0000-0000-0000-000000000000'::uuid);
    RAISE EXCEPTION 'TEST FAILED: Anon should be denied';
EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'SUCCESS: Anon denied (insufficient_privilege)';
END;
\$\$;

-- TEST 2: Authenticated User
SET ROLE authenticated;
DO \$\$
BEGIN
    PERFORM catalog.rpc_resolve_currency_by_geography('00000000-0000-0000-0000-000000000000'::uuid);
    RAISE EXCEPTION 'TEST FAILED: Authenticated should be denied';
EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'SUCCESS: Authenticated denied (insufficient_privilege)';
END;
\$\$;

-- TEST 3: Service Role (Backend API)
SET ROLE service_role;
DO \$\$
BEGIN
    PERFORM catalog.rpc_resolve_currency_by_geography('00000000-0000-0000-0000-000000000000'::uuid);
    RAISE NOTICE 'SUCCESS: Service Role allowed';
END;
\$\$;
