npx supabase db query "SELECT column_name FROM information_schema.columns WHERE table_schema = 'integration' AND table_name = 'outbox_events';" --linked
