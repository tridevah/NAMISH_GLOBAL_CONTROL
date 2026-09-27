BEGIN;
EXPLAIN ANALYZE
WITH map AS (
    SELECT id as correct_batch_id, entity_type,
           CASE
               WHEN entity_type IN ('PINCODE', 'POST_OFFICE') THEN 'PIN CODE.csv'
               WHEN entity_type = 'PIN_VILLAGE' THEN 'Pincodeto_Village_Mapping.xlsx'
               WHEN entity_type = 'PIN_URBAN_LOCAL_BODY' THEN 'Pincodeto_Urban_Mapping.xlsx'
               ELSE SUBSTRING(logical_batch_key FROM '^(.*)!' || entity_type || '![0-9]+$')
           END as internal_member_or_sheet
    FROM data_imports.batches
    WHERE release_id = 'b3573f9b-1eff-47d5-8cdf-fba3eba74b19'
)
UPDATE staging.geography_imports s
SET batch_id = map.correct_batch_id
FROM map
WHERE s.release_id = 'b3573f9b-1eff-47d5-8cdf-fba3eba74b19'
  AND s.entity_type = map.entity_type
  AND s.internal_member_or_sheet = map.internal_member_or_sheet
  AND s.batch_id != map.correct_batch_id;
ROLLBACK;
