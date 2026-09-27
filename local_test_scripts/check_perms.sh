npx supabase db query "SELECT has_table_privilege('gc_dispatcher_worker', 'integration.outbox_events', 'SELECT, UPDATE');" --linked
