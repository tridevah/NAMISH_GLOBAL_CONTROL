SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_schema='catalog' AND table_name='catalog_releases';

SELECT tc.constraint_name, kcu.column_name 
FROM information_schema.table_constraints tc 
JOIN information_schema.key_column_usage kcu 
  ON tc.constraint_name = kcu.constraint_name 
WHERE tc.table_schema = 'catalog' AND tc.table_name = 'catalog_releases' AND tc.constraint_type = 'UNIQUE';
