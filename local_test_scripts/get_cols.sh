npx supabase db query "SELECT column_name, data_type FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'gst_rate_master';" --linked
