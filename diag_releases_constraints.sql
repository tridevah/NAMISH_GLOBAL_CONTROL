SELECT conname, pg_get_constraintdef(c.oid) AS constraint_def
FROM pg_constraint c
JOIN pg_namespace n ON n.oid = c.connamespace
WHERE n.nspname = 'data_imports' AND c.conrelid = 'data_imports.releases'::regclass;
