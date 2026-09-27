npx supabase db query "SELECT table_name FROM information_schema.tables WHERE table_schema = 'integration' AND table_name LIKE '%endpoint%';" --linked
