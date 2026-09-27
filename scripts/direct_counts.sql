BEGIN TRANSACTION READ ONLY;
-- 1
SELECT COUNT(*) AS total_units FROM catalog.geography_units;
-- 2
SELECT country_id, COUNT(*) FROM catalog.geography_units GROUP BY country_id;
-- 3
SELECT id AS india_id FROM catalog.countries WHERE iso3 = 'IND';
-- 4, 5
SELECT status, COUNT(*) FROM catalog.geography_units WHERE country_id = (SELECT id FROM catalog.countries WHERE iso3 = 'IND') GROUP BY status;
-- 6
SELECT gl.level_key, u.status, COUNT(*) 
FROM catalog.geography_units u 
JOIN catalog.geography_levels gl ON gl.id = u.geography_level_id 
WHERE u.country_id = (SELECT id FROM catalog.countries WHERE iso3 = 'IND') 
GROUP BY gl.level_key, u.status;
-- 8
SELECT COUNT(DISTINCT id) FROM catalog.geography_units;
-- 9
SELECT u.id, COUNT(*) 
FROM catalog.geography_units u 
JOIN catalog.geography_levels gl ON gl.id = u.geography_level_id 
LEFT JOIN catalog.geography_units pu ON pu.id = u.parent_geography_unit_id 
GROUP BY u.id HAVING COUNT(*) > 1;
-- 10
SELECT COUNT(*) FROM catalog.geography_units u 
LEFT JOIN catalog.countries c ON c.id = u.country_id 
LEFT JOIN catalog.geography_levels gl ON gl.id = u.geography_level_id 
WHERE c.id IS NULL OR gl.id IS NULL;
-- 11, 12, 13
SELECT DISTINCT gl.level_key FROM catalog.geography_units u JOIN catalog.geography_levels gl ON gl.id = u.geography_level_id;
-- 14
SELECT COUNT(*) FROM catalog.development_blocks;
SELECT COUNT(*) FROM catalog.block_districts;
ROLLBACK;
