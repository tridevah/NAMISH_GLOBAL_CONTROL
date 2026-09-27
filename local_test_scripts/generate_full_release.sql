BEGIN;
SET LOCAL search_path = '';

DELETE FROM catalog.catalog_releases WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
INSERT INTO catalog.catalog_releases (id, version, status, hsn_sac_intentionally_empty, tax_profiles_intentionally_empty, units_intentionally_empty)
VALUES ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'v7.0.0', 'DRAFT', false, false, false);

-- HSN
INSERT INTO catalog.catalog_release_items (item_id, release_id, item_type, payload)
SELECT
    id_val, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'HSN_SAC',
    jsonb_build_object(
        'id', id_val,
        'code', 'HSN' || i,
        'type', 'HSN',
        'description', 'Generated HSN ' || i,
        'category', 'GOODS'
    )
FROM (SELECT gen_random_uuid() AS id_val, i FROM generate_series(1, 22607) i) sub;

-- UNIT
INSERT INTO catalog.catalog_release_items (item_id, release_id, item_type, payload)
SELECT
    id_val, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'UNIT',
    jsonb_build_object(
        'id', id_val,
        'code', 'U' || i,
        'canonical_code', 'U' || i,
        'name', 'Unit ' || i,
        'status', CASE WHEN i <= 1764 THEN 'ACTIVE' ELSE 'INACTIVE' END,
        'is_business', false,
        'business_name', 'BusUnit ' || i,
        'short_name', 'U' || i
    )
FROM (SELECT gen_random_uuid() AS id_val, i FROM generate_series(1, 2144) i) sub;

-- TAX
INSERT INTO catalog.catalog_release_items (item_id, release_id, item_type, payload)
SELECT
    id_val, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'TAX_PROFILE',
    jsonb_build_object(
        'id', id_val,
        'name', 'Tax ' || i,
        'rate', 18.00,
        'category', 'STANDARD',
        'is_current', CASE WHEN i = 15 THEN false ELSE true END,
        'status', CASE WHEN i = 15 THEN 'INACTIVE' ELSE 'ACTIVE' END,
        'usage_scope', CASE 
            WHEN i <= 3 THEN 'COMPOSITION'
            WHEN i <= 10 THEN 'TRANSACTION_RATE'
            ELSE 'TRANSACTION_RATE'
        END,
        'effective_from', CASE WHEN i = 15 THEN '2020-01-01T00:00:00Z' ELSE '2026-01-01T00:00:00Z' END,
        'effective_to', CASE WHEN i = 15 THEN '2025-12-31T23:59:59Z' ELSE null END,
        'erp_visibility', 'GENERAL',
        'valuation_basis', 'TRANSACTION_VALUE',
        'itc_policy', 'DEFAULT',
        'conditions', CASE 
            WHEN i >= 4 AND i <= 10 THEN '{"required_party_type": "SPECIFIC"}'::jsonb 
            ELSE '{}'::jsonb 
        END
    )
FROM (SELECT gen_random_uuid() AS id_val, i FROM generate_series(1, 15) i) sub;

DROP TRIGGER IF EXISTS trg_publish_release ON catalog.catalog_releases;
CREATE TRIGGER trg_publish_release
BEFORE UPDATE ON catalog.catalog_releases
FOR EACH ROW EXECUTE FUNCTION catalog.fn_publish_release();

UPDATE catalog.catalog_releases SET status = 'PUBLISHED' WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
COMMIT;
