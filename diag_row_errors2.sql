SELECT is_nullable FROM information_schema.columns WHERE table_schema = 'data_imports' AND table_name = 'row_errors' AND column_name = 'batch_id';
