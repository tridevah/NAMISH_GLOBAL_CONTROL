SELECT conname, pg_get_constraintdef(c.oid) AS constraint_def
FROM pg_constraint c
JOIN pg_namespace n ON n.oid = c.connamespace
WHERE n.nspname = 'catalog' AND c.conrelid = 'catalog.country_tax_coverage'::regclass;
