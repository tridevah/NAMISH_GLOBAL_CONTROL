npx supabase db query "SELECT n.nspname, c.relname FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE c.relname = 'catalog_sync_control';" --linked
npx supabase db query "SELECT n.nspname, c.relname FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE c.relname = 'catalog_release_items';" --linked
npx supabase db query "SELECT conname, pg_get_constraintdef(oid) FROM pg_constraint WHERE conrelid = 'catalog.catalog_release_items'::regclass;" --linked
