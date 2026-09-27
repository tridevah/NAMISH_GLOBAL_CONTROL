-- Migration: Public RPC wrappers for release management
-- Scope:     GC database

BEGIN;
SET LOCAL search_path = '';

CREATE OR REPLACE FUNCTION public.create_business_release_wrapper(p_version TEXT, p_include_cleanup BOOLEAN)
RETURNS UUID
LANGUAGE sql
SECURITY DEFINER
SET search_path = catalog, pg_temp
AS $$
    SELECT catalog.create_business_release(p_version, p_include_cleanup);
$$;

REVOKE ALL ON FUNCTION public.create_business_release_wrapper(TEXT, BOOLEAN) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.create_business_release_wrapper(TEXT, BOOLEAN) TO service_role;
ALTER FUNCTION public.create_business_release_wrapper(TEXT, BOOLEAN) OWNER TO postgres;

CREATE OR REPLACE FUNCTION public.publish_draft_release_wrapper(p_release_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = catalog, pg_temp
AS $$
    SELECT catalog.publish_draft_release(p_release_id);
$$;

REVOKE ALL ON FUNCTION public.publish_draft_release_wrapper(UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.publish_draft_release_wrapper(UUID) TO service_role;
ALTER FUNCTION public.publish_draft_release_wrapper(UUID) OWNER TO postgres;

COMMIT;
