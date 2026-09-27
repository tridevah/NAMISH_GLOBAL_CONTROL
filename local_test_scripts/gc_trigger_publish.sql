-- GC Publish Mock
BEGIN;
SET LOCAL search_path = '';

DELETE FROM catalog.catalog_releases WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

INSERT INTO catalog.catalog_releases (id, version, status, hsn_sac_intentionally_empty, tax_profiles_intentionally_empty, units_intentionally_empty)
VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'v6.0.0', 'DRAFT', true, false, true);

INSERT INTO catalog.catalog_release_items (item_id, release_id, item_type, payload)
SELECT
    id_val,
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'TAX_PROFILE',
    jsonb_build_object(
        'id', id_val,
        'name', 'Tax ' || i,
        'rate', 18.00,
        'category', 'STANDARD',
        'is_current', true,
        'status', 'ACTIVE',
        'usage_scope', 'TRANSACTION_RATE',
        'effective_from', '2026-01-01T00:00:00Z',
        'effective_to', null,
        'erp_visibility', 'GENERAL',
        'valuation_basis', 'TRANSACTION_VALUE',
        'itc_policy', 'DEFAULT',
        'conditions', '{}'::jsonb
    )
FROM (
    SELECT gen_random_uuid() AS id_val, i FROM generate_series(1, 15) i
) sub;

DROP TRIGGER IF EXISTS trg_publish_release ON catalog.catalog_releases;
CREATE TRIGGER trg_publish_release
BEFORE UPDATE ON catalog.catalog_releases
FOR EACH ROW EXECUTE FUNCTION catalog.fn_publish_release();

UPDATE catalog.catalog_releases SET status = 'PUBLISHED' WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

COMMIT;
