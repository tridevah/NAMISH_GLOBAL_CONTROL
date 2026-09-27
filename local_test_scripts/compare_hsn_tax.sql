WITH pub AS (
  SELECT id FROM catalog.catalog_releases WHERE status = 'PUBLISHED' ORDER BY created_at DESC LIMIT 1
),
pub_items AS (
  SELECT item_type, item_id, payload FROM catalog.catalog_release_items 
  WHERE release_id = (SELECT id FROM pub) AND item_type IN ('HSN_SAC', 'TAX_PROFILE')
),
draft_items AS (
  SELECT item_type, item_id, payload FROM catalog.catalog_release_items 
  WHERE release_id = 'ca7c5ea6-2f52-44de-bd42-f46b253a4d63' AND item_type IN ('HSN_SAC', 'TAX_PROFILE')
),
diff AS (
  SELECT 
    COALESCE(p.item_type, d.item_type) as item_type,
    COALESCE(p.item_id, d.item_id) as item_id,
    p.payload as pub_payload,
    d.payload as draft_payload
  FROM pub_items p
  FULL OUTER JOIN draft_items d ON p.item_type = d.item_type AND p.item_id = d.item_id
)
SELECT 
  count(*) as total_items,
  count(*) filter (where pub_payload IS NULL) as missing_in_pub,
  count(*) filter (where draft_payload IS NULL) as missing_in_draft,
  count(*) filter (where pub_payload IS NOT NULL AND draft_payload IS NOT NULL AND pub_payload::text != draft_payload::text) as modified
FROM diff;
