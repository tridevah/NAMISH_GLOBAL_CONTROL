npx supabase db query "SELECT status, COUNT(*) FROM integration.outbox_events GROUP BY status;" --linked
