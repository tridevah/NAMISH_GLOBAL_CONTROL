-- UNAPPLIED FORWARD CORRECTION
-- Target: urxgjgwrwpeplxoeobhz.supabase.co (public schema)
--
-- Problem:
--   SET search_path TO pg_catalog causes COALESCE to resolve in the pg_catalog
--   search path.  pg_catalog.coalesce does not exist as a qualified function name;
--   COALESCE is a SQL keyword handled by the parser, not a catalogued function.
--   Result: "function pg_catalog.coalesce(jsonb, jsonb) does not exist" (code 42883).
--
-- Fix: one-line replacement only.  No other change to signature, security,
--   ownership, settings, grants, or historical migration file.

CREATE OR REPLACE FUNCTION public.rpc_get_country_currencies(
  p_iso2 pg_catalog.text DEFAULT NULL
)
RETURNS pg_catalog.jsonb AS $$
DECLARE
  v_result pg_catalog.jsonb;
BEGIN
  SELECT pg_catalog.jsonb_agg(
    pg_catalog.jsonb_build_object(
      'iso_alpha_code',   cu.iso_alpha_code,
      'iso_numeric_code', cu.iso_numeric_code,
      'name',             cu.name,
      'default_symbol',   cu.default_symbol,
      'native_symbol',    cu.native_symbol,
      'minor_units',      cu.minor_units,
      'status',           cu.status,
      'country_iso2',     co.iso2,
      'country_iso3',     co.iso3,
      'country_name',     co.display_name
    )
    ORDER BY co.iso2
  ) INTO v_result
  FROM catalog.countries co
  JOIN catalog.currencies cu ON cu.iso_alpha_code = co.default_currency_code
  WHERE cu.status = 'ACTIVE'
    AND (p_iso2 IS NULL OR pg_catalog.upper(co.iso2) = pg_catalog.upper(p_iso2));

  RETURN COALESCE(v_result, '[]'::pg_catalog.jsonb);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO pg_catalog;
