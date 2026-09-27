docker exec -i disposable_test_123 psql -U postgres -c "
CREATE TABLE IF NOT EXISTS catalog.hsn_sac AS SELECT * FROM public.hsn_sac;
ALTER TABLE catalog.hsn_sac RENAME COLUMN type TO goods_or_service;
ALTER TABLE catalog.hsn_sac RENAME COLUMN category TO chapter;
ALTER TABLE catalog.hsn_sac ADD COLUMN heading TEXT;
CREATE TABLE IF NOT EXISTS catalog.measurement_units AS SELECT * FROM public.measurement_units;
ALTER TABLE catalog.measurement_units RENAME COLUMN code TO standard_code;
"
