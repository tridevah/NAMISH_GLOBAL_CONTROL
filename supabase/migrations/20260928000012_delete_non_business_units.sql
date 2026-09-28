-- Migration 20260928000012_delete_non_business_units.sql (GC)
BEGIN;

CREATE TABLE IF NOT EXISTS catalog.measurement_units_backup_20260928 AS 
SELECT * FROM catalog.measurement_units WHERE is_business = false;

WITH referenced_units AS (
    SELECT measurement_unit_id as id FROM catalog.uqc WHERE measurement_unit_id IS NOT NULL
    UNION
    SELECT from_unit_id as id FROM catalog.unit_conversions WHERE from_unit_id IS NOT NULL
    UNION
    SELECT to_unit_id as id FROM catalog.unit_conversions WHERE to_unit_id IS NOT NULL
)
DELETE FROM catalog.measurement_units
WHERE is_business = false
  AND id NOT IN (SELECT id FROM referenced_units);

-- Enforce that no non-business units can be inserted in the future if desired, but wait: we have 16 referenced non-business units that we are preserving! So we can't add a global CHECK (is_business = true) to the table. We'll skip the constraint on the table, but we will ensure future publications exclude them. Actually the ERP-facing master in ERP is integration.global_unit_catalog. That table CAN have a CHECK constraint.

COMMIT;
