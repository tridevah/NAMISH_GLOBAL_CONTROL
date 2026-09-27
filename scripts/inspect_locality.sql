BEGIN TRANSACTION READ ONLY;
SELECT display_name, official_name, official_code FROM catalog.geography_units u 
JOIN catalog.geography_levels gl ON gl.id = u.geography_level_id 
WHERE gl.level_key = 'LOCALITY' LIMIT 5;
ROLLBACK;
