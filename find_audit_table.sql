SELECT table_schema, table_name 
FROM information_schema.tables 
WHERE table_name ILIKE '%audit%' OR table_name ILIKE '%exception%' OR table_name ILIKE '%import%' OR table_name ILIKE '%log%';
