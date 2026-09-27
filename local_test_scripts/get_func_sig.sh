npx supabase db query "SELECT proname, pg_get_function_identity_arguments(oid) FROM pg_proc WHERE proname LIKE '%claim_delivery%';" --linked
