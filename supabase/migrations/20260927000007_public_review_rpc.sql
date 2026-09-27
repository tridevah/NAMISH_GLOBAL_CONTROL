-- Migration: Add Review RPC
-- Scope: GC database
BEGIN;
SET LOCAL search_path = '';

CREATE OR REPLACE FUNCTION public.get_release_review(p_draft_id UUID)
RETURNS JSONB
LANGUAGE sql
SECURITY DEFINER
SET search_path = catalog, integration, public, pg_temp
AS $$
WITH baseline AS (
  SELECT id, version, status 
  FROM catalog.catalog_releases 
  WHERE status = 'PUBLISHED' 
  ORDER BY created_at DESC 
  LIMIT 1
),
baseline_items AS (
  SELECT item_type, item_id, payload 
  FROM catalog.catalog_release_items 
  WHERE release_id = (SELECT id FROM baseline)
),
draft_items AS (
  SELECT item_type, item_id, payload 
  FROM catalog.catalog_release_items 
  WHERE release_id = p_draft_id
),
diff AS (
  SELECT 
    COALESCE(p.item_type, d.item_type) as item_type,
    count(*) filter (where p.payload IS NULL) as added,
    count(*) filter (where d.payload IS NULL) as removed,
    count(*) filter (where p.payload IS NOT NULL AND d.payload IS NOT NULL AND p.payload::text != d.payload::text) as modified,
    count(*) filter (where p.payload IS NOT NULL AND d.payload IS NOT NULL AND p.payload::text = d.payload::text) as unchanged
  FROM baseline_items p
  FULL OUTER JOIN draft_items d ON p.item_type = d.item_type AND p.item_id = d.item_id
  GROUP BY COALESCE(p.item_type, d.item_type)
),
draft_release AS (
  SELECT id, version, status FROM catalog.catalog_releases WHERE id = p_draft_id
),
outbox AS (
  SELECT e.id as event_id, e.status as event_status, 
         d.id as delivery_id, d.status as delivery_status,
         s.endpoint_id
  FROM integration.outbox_events e
  LEFT JOIN integration.subscriptions s ON s.topic = 'catalog.release.published'
  LEFT JOIN integration.event_deliveries d ON d.event_id = e.id AND d.subscription_id = s.id
  WHERE e.topic = 'catalog.release.published' 
    AND (e.payload->>'id')::uuid = p_draft_id
  ORDER BY e.created_at DESC
  LIMIT 1
)
SELECT jsonb_build_object(
  'draft_id', dr.id,
  'draft_version', dr.version,
  'draft_status', dr.status,
  'baseline_release_id', b.id,
  'baseline_version', b.version,
  'diffs', (SELECT jsonb_object_agg(item_type, jsonb_build_object(
      'added', added, 'removed', removed, 'modified', modified, 'unchanged', unchanged
    )) FROM diff),
  'delivery_info', (
    SELECT CASE WHEN o.event_id IS NULL THEN NULL
           ELSE jsonb_build_object(
             'event_id', o.event_id,
             'event_status', o.event_status,
             'endpoint_id', o.endpoint_id,
             'delivery_id', o.delivery_id,
             'delivery_status', COALESCE(o.delivery_status, 'PENDING_DELIVERY')
           ) END
    FROM outbox o
  )
)
FROM draft_release dr
LEFT JOIN baseline b ON true;
$$;

REVOKE ALL ON FUNCTION public.get_release_review(UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_release_review(UUID) TO service_role;
ALTER FUNCTION public.get_release_review(UUID) OWNER TO postgres;

COMMIT;
