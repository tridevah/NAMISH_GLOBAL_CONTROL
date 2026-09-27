npx supabase db query "SELECT tgname, proname FROM pg_trigger t JOIN pg_proc p ON t.tgfoid = p.oid WHERE tgrelid = 'integration.outbox_events'::regclass;" --linked
