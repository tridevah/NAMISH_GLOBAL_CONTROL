-- Migration: Compare Catalog Releases RPC
-- Scope:     GC database

BEGIN;
SET LOCAL search_path = '';

CREATE OR REPLACE FUNCTION catalog.compare_catalog_releases(p_pub_id UUID, p_draft_id UUID)
RETURNS JSONB
LANGUAGE sql
SECURITY DEFINER
SET search_path = catalog, pg_temp
AS $$
WITH pub_items AS (
  SELECT item_type, item_id, payload FROM catalog.catalog_release_items WHERE release_id = p_pub_id
),
draft_items AS (
  SELECT item_type, item_id, payload FROM catalog.catalog_release_items WHERE release_id = p_draft_id
),
diff AS (
  SELECT 
    COALESCE(p.item_type, d.item_type) as item_type,
    COALESCE(p.item_id, d.item_id) as item_id,
    p.payload as pub_payload,
    d.payload as draft_payload
  FROM pub_items p
  FULL OUTER JOIN draft_items d ON p.item_type = d.item_type AND p.item_id = d.item_id
),
summary AS (
  SELECT 
    item_type,
    count(*) filter (where pub_payload IS NULL) as added,
    count(*) filter (where draft_payload IS NULL) as removed,
    count(*) filter (where pub_payload IS NOT NULL AND draft_payload IS NOT NULL AND pub_payload::text != draft_payload::text) as modified,
    count(*) filter (where pub_payload IS NOT NULL AND draft_payload IS NOT NULL AND pub_payload::text = draft_payload::text) as unchanged
  FROM diff
  GROUP BY item_type
)
SELECT jsonb_object_agg(
  item_type, 
  jsonb_build_object(
    'added', added,
    'removed', removed,
    'modified', modified,
    'unchanged', unchanged
  )
) FROM summary;
$$;

REVOKE ALL ON FUNCTION catalog.compare_catalog_releases(UUID, UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION catalog.compare_catalog_releases(UUID, UUID) TO service_role;
ALTER FUNCTION catalog.compare_catalog_releases(UUID, UUID) OWNER TO postgres;

CREATE OR REPLACE FUNCTION public.compare_catalog_releases_wrapper(p_pub_id UUID, p_draft_id UUID)
RETURNS JSONB
LANGUAGE sql
SECURITY DEFINER
SET search_path = catalog, pg_temp
AS $$
    SELECT catalog.compare_catalog_releases(p_pub_id, p_draft_id);
$$;

REVOKE ALL ON FUNCTION public.compare_catalog_releases_wrapper(UUID, UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.compare_catalog_releases_wrapper(UUID, UUID) TO service_role;
ALTER FUNCTION public.compare_catalog_releases_wrapper(UUID, UUID) OWNER TO postgres;

COMMIT;
