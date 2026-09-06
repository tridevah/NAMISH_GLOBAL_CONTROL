-- Migration 20260904000003: Expose catalog schema via public views
-- 
-- The Supabase project exposes only public + graphql_public schemas via PostgREST.
-- catalog schema tables are inaccessible via PostgREST (HTTP 406 Invalid schema).
-- This migration creates thin public views + grants so the Next.js app's
-- Supabase JS client can reach catalog data via supabase.from('...').
--
-- No data is moved. Views are read-only (no INSTEAD OF triggers).
-- No Geography or Currency DML.

BEGIN;

-- ============================================================
-- SECTION 1: CREATE PUBLIC READ-ONLY VIEWS
-- ============================================================

-- Countries (already accessible via existing user RLS but expose for consistency)
CREATE OR REPLACE VIEW public.countries AS SELECT * FROM catalog.countries;
CREATE OR REPLACE VIEW public.currencies AS SELECT * FROM catalog.currencies;
CREATE OR REPLACE VIEW public.jurisdictions AS SELECT * FROM catalog.jurisdictions;
CREATE OR REPLACE VIEW public.tax_authorities AS SELECT * FROM catalog.tax_authorities;
CREATE OR REPLACE VIEW public.tax_codes AS SELECT * FROM catalog.tax_codes;
CREATE OR REPLACE VIEW public.tax_rates AS SELECT * FROM catalog.tax_rates;
CREATE OR REPLACE VIEW public.tax_regimes AS SELECT * FROM catalog.tax_regimes;
CREATE OR REPLACE VIEW public.tax_components AS SELECT * FROM catalog.tax_components;
CREATE OR REPLACE VIEW public.tax_rate_component_sets AS SELECT * FROM catalog.tax_rate_component_sets;
CREATE OR REPLACE VIEW public.tax_rate_component_lines AS SELECT * FROM catalog.tax_rate_component_lines;
CREATE OR REPLACE VIEW public.geography_units AS SELECT * FROM catalog.geography_units;
CREATE OR REPLACE VIEW public.geography_levels AS SELECT * FROM catalog.geography_levels;
CREATE OR REPLACE VIEW public.development_blocks AS SELECT * FROM catalog.development_blocks;
CREATE OR REPLACE VIEW public.hsn_sac AS SELECT * FROM catalog.hsn_sac;
CREATE OR REPLACE VIEW public.country_tax_coverage AS SELECT * FROM catalog.country_tax_coverage;
CREATE OR REPLACE VIEW public.applicability_scopes AS SELECT * FROM catalog.applicability_scopes;
CREATE OR REPLACE VIEW public.uqc AS SELECT * FROM catalog.uqc;

-- ============================================================
-- SECTION 2: GRANT SELECT TO anon AND authenticated ROLES
-- (service_role already bypasses everything)
-- ============================================================

DO $$
DECLARE
  v_views TEXT[] := ARRAY[
    'countries','currencies','jurisdictions','tax_authorities',
    'tax_codes','tax_rates','tax_regimes','tax_components',
    'tax_rate_component_sets','tax_rate_component_lines',
    'geography_units','geography_levels','development_blocks',
    'hsn_sac','country_tax_coverage','applicability_scopes','uqc'
  ];
  v_view TEXT;
BEGIN
  FOREACH v_view IN ARRAY v_views LOOP
    EXECUTE format('GRANT SELECT ON public.%I TO anon', v_view);
    EXECUTE format('GRANT SELECT ON public.%I TO authenticated', v_view);
    RAISE NOTICE 'Granted SELECT on public.%', v_view;
  END LOOP;
END $$;

-- ============================================================
-- SECTION 3: VERIFY VIEWS ARE ACCESSIBLE
-- ============================================================

DO $$
DECLARE
  v_count INT;
BEGIN
  SELECT count(*) INTO v_count FROM public.countries WHERE iso2 = 'IN';
  IF v_count != 1 THEN RAISE EXCEPTION 'public.countries view verification failed: expected 1 India row, got %', v_count; END IF;

  SELECT count(*) INTO v_count FROM public.tax_regimes WHERE code = 'IN_GST';
  IF v_count != 1 THEN RAISE EXCEPTION 'public.tax_regimes view verification failed: expected 1 IN_GST row, got %', v_count; END IF;

  SELECT count(*) INTO v_count FROM public.tax_components WHERE code IN ('CGST','SGST','UTGST','IGST');
  IF v_count != 4 THEN RAISE EXCEPTION 'public.tax_components view verification failed: expected 4, got %', v_count; END IF;

  RAISE NOTICE 'All public views verified — catalog schema now reachable via PostgREST';
END $$;

COMMIT;
