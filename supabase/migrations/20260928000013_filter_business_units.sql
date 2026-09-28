-- Migration 20260928000013_filter_business_units.sql (GC)
BEGIN;

CREATE OR REPLACE VIEW public.measurement_units AS
SELECT 
    id,
    canonical_code,
    standard_code,
    name,
    symbol,
    category,
    aliases,
    status,
    source_status,
    source,
    source_version,
    description,
    created_at,
    updated_at,
    business_name,
    short_name,
    is_business
FROM catalog.measurement_units
WHERE is_business = true;

COMMIT;
