SELECT column_name, data_type, is_nullable FROM information_schema.columns WHERE table_schema = 'data_imports' AND table_name = 'releases';
