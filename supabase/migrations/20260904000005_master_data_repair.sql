-- Migration 20260904000005: Master Data Repair
-- Adds missing country_id to master datasets and recreates public views

BEGIN;

-- 1. Add country_id to hsn_sac and gst_rate_master
ALTER TABLE catalog.hsn_sac
    ADD COLUMN IF NOT EXISTS country_id UUID REFERENCES catalog.countries(id);

ALTER TABLE catalog.gst_rate_master
    ADD COLUMN IF NOT EXISTS country_id UUID REFERENCES catalog.countries(id);

-- 2. Populate country_id with India mapping
UPDATE catalog.hsn_sac
   SET country_id = (SELECT id FROM catalog.countries WHERE iso2 = 'IN')
 WHERE country_id IS NULL;

UPDATE catalog.gst_rate_master
   SET country_id = (SELECT id FROM catalog.countries WHERE iso2 = 'IN')
 WHERE country_id IS NULL;

-- 3. Enforce NOT NULL on country_id
ALTER TABLE catalog.hsn_sac
    ALTER COLUMN country_id SET NOT NULL;

ALTER TABLE catalog.gst_rate_master
    ALTER COLUMN country_id SET NOT NULL;

-- 4. Recreate public views to include all actual columns including country_id
DROP VIEW IF EXISTS public.gst_rate_master CASCADE;
CREATE VIEW public.gst_rate_master AS SELECT * FROM catalog.gst_rate_master;
GRANT SELECT ON public.gst_rate_master TO anon, authenticated;

DROP VIEW IF EXISTS public.hsn_sac CASCADE;
CREATE VIEW public.hsn_sac AS SELECT * FROM catalog.hsn_sac;
GRANT SELECT ON public.hsn_sac TO anon, authenticated;

-- 5. Force PostgREST schema cache reload
NOTIFY pgrst, 'reload schema';

COMMIT;
