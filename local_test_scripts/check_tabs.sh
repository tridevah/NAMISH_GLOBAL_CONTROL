npx supabase db query "SELECT table_schema, table_name, table_type FROM information_schema.tables WHERE table_name IN ('hsn_sac', 'measurement_units');" --linked
npx supabase db query "SELECT column_name, data_type FROM information_schema.columns WHERE table_schema = 'catalog' AND table_name IN ('hsn_sac', 'measurement_units');" --linked
