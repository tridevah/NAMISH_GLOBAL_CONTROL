BEGIN TRANSACTION READ ONLY;
-- R16 status
SELECT id, release_name, status, completed_at FROM data_imports.releases WHERE id = '5fac63d7-0101-43c5-8867-bd75ff609861';
ROLLBACK;
