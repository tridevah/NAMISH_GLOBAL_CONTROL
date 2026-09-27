BEGIN;
SET LOCAL search_path = '';

DELETE FROM catalog.catalog_releases WHERE id = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
INSERT INTO catalog.catalog_releases (id, version, status, hsn_sac_intentionally_empty, tax_profiles_intentionally_empty, units_intentionally_empty)
VALUES ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'v8.0.0', 'DRAFT', false, false, false);
COMMIT;
