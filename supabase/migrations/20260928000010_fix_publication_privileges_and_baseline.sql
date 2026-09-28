-- Migration 20260927000010: Fix publication privileges and baseline logic
-- Scope: GC database

BEGIN;

-- 1. Restrict internal functions explicitly (Revoke PUBLIC)
REVOKE ALL ON FUNCTION catalog.create_business_release(TEXT, BOOLEAN) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION catalog.create_business_release(TEXT, BOOLEAN) TO service_role;

-- Drop old publish_draft_release because signature is changing
DROP FUNCTION IF EXISTS catalog.publish_draft_release(UUID);
DROP FUNCTION IF EXISTS public.publish_draft_release_wrapper(UUID);

-- 2. Update get_release_review to order by release_sequence instead of created_at
CREATE OR REPLACE FUNCTION public.get_release_review(p_draft_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = catalog, integration, public, pg_temp
AS $fn$
DECLARE
    v_draft    RECORD;
    v_baseline RECORD;
    v_counts   JSONB;
    v_diffs    JSONB;
    v_delivery JSONB;
    v_event    RECORD;
BEGIN
    SELECT id, version, status
    INTO v_draft
    FROM catalog.catalog_releases
    WHERE id = p_draft_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('error', 'DRAFT_NOT_FOUND');
    END IF;

    -- Explicit baseline excluding self-comparison, ordered by release_sequence
    SELECT id, version, release_sequence
    INTO v_baseline
    FROM catalog.catalog_releases
    WHERE status = 'PUBLISHED' AND id != p_draft_id
    ORDER BY release_sequence DESC NULLS LAST
    LIMIT 1;

    SELECT jsonb_object_agg(item_type, cnt)
    INTO v_counts
    FROM (
        SELECT item_type, count(*) AS cnt
        FROM catalog.catalog_release_items
        WHERE release_id = p_draft_id
        GROUP BY item_type
    ) t;

    IF v_baseline.id IS NOT NULL THEN
        WITH baseline_items AS (
            SELECT item_type, item_id, payload 
            FROM catalog.catalog_release_items 
            WHERE release_id = v_baseline.id
        ),
        draft_items AS (
            SELECT item_type, item_id, payload 
            FROM catalog.catalog_release_items 
            WHERE release_id = p_draft_id
        )
        SELECT jsonb_object_agg(item_type, jsonb_build_object(
            'added', added,
            'removed', removed,
            'modified', modified,
            'unchanged', unchanged
        ))
        INTO v_diffs
        FROM (
            SELECT
                COALESCE(p.item_type, d.item_type) AS item_type,
                count(*) FILTER (WHERE p.item_id IS NULL)  AS added,
                count(*) FILTER (WHERE d.item_id IS NULL)  AS removed,
                count(*) FILTER (
                    WHERE p.item_id IS NOT NULL
                      AND d.item_id IS NOT NULL
                      AND p.payload::text IS DISTINCT FROM d.payload::text
                ) AS modified,
                count(*) FILTER (
                    WHERE p.item_id IS NOT NULL
                      AND d.item_id IS NOT NULL
                      AND p.payload::text IS NOT DISTINCT FROM d.payload::text
                ) AS unchanged
            FROM baseline_items p
            FULL OUTER JOIN draft_items d
                ON p.item_type = d.item_type AND p.item_id = d.item_id
            GROUP BY COALESCE(p.item_type, d.item_type)
        ) diff_t;
    END IF;

    IF v_draft.status = 'PUBLISHED' THEN
        SELECT e.id, e.status AS event_status
        INTO v_event
        FROM integration.outbox_events e
        WHERE e.event_type = 'catalog.release.published'
          AND (e.payload->>'release_id')::uuid = p_draft_id
        ORDER BY e.created_at DESC
        LIMIT 1;

        IF NOT FOUND THEN
            v_delivery := jsonb_build_object(
                'lookup_status', 'EVENT_NOT_FOUND',
                'detail', 'No outbox event matched event_type=catalog.release.published and payload.release_id=' || p_draft_id::text
            );
        ELSE
            SELECT jsonb_build_object(
                'event_id', v_event.id,
                'event_status', v_event.event_status,
                'deliveries', COALESCE(
                    (SELECT jsonb_agg(jsonb_build_object(
                        'endpoint_id', ds.endpoint_id,
                        'endpoint_url', ds.endpoint_url,
                        'recipient_identity', ds.recipient_identity,
                        'delivery_status', ds.status,
                        'attempt_count', ds.attempt_count,
                        'last_attempt_http_status', (
                            SELECT da.http_status
                            FROM integration.delivery_attempts da
                            WHERE da.event_id = v_event.id AND da.endpoint_id = ds.endpoint_id
                            ORDER BY da.attempt_number DESC
                            LIMIT 1
                        )
                    ))
                    FROM integration.delivery_state ds
                    WHERE ds.event_id = v_event.id),
                    '[]'::jsonb
                ),
                'subscriptions', (
                    SELECT jsonb_agg(jsonb_build_object(
                        'subscription_id', ts.id,
                        'endpoint_id', ts.endpoint_id,
                        'endpoint_url', we.url,
                        'endpoint_status', we.status,
                        'subscription_status', ts.status
                    ))
                    FROM integration.topic_subscriptions ts
                    JOIN integration.webhook_endpoints we ON we.id = ts.endpoint_id
                    WHERE ts.topic = 'catalog.release.published'
                )
            )
            INTO v_delivery;
        END IF;
    ELSE
        SELECT jsonb_build_object(
            'event_id', null,
            'event_status', 'NOT_YET_PUBLISHED',
            'subscriptions', (
                SELECT jsonb_agg(jsonb_build_object(
                    'subscription_id', ts.id,
                    'endpoint_id', ts.endpoint_id,
                    'endpoint_url', we.url,
                    'endpoint_status', we.status,
                    'subscription_status', ts.status
                ))
                FROM integration.topic_subscriptions ts
                JOIN integration.webhook_endpoints we ON we.id = ts.endpoint_id
                WHERE ts.topic = 'catalog.release.published'
            )
        )
        INTO v_delivery;
    END IF;

    RETURN jsonb_build_object(
        'draft_id',             v_draft.id,
        'draft_version',        v_draft.version,
        'draft_status',         v_draft.status,
        'baseline_release_id',  v_baseline.id,
        'baseline_version',     v_baseline.version,
        'baseline_sequence',    v_baseline.release_sequence,
        'counts',               COALESCE(v_counts, '{}'::jsonb),
        'diffs',                v_diffs,
        'delivery',             v_delivery
    );
END;
$fn$;
-- Ensure review wrapper privileges are still correct
REVOKE ALL ON FUNCTION public.get_release_review(UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_release_review(UUID) TO service_role;
ALTER FUNCTION public.get_release_review(UUID) OWNER TO postgres;

-- 3. Update publish_draft_release to take baseline expected ID
CREATE OR REPLACE FUNCTION catalog.publish_draft_release(p_release_id UUID, p_expected_baseline UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = catalog, integration, public, pg_temp
AS $fn$
DECLARE
    v_release RECORD;
    v_event_id UUID;
    v_actual_baseline UUID;
BEGIN
    SELECT id, status, version, release_sequence INTO v_release
    FROM catalog.catalog_releases
    WHERE id = p_release_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('published', false, 'error', 'RELEASE_NOT_FOUND');
    END IF;

    IF v_release.status = 'PUBLISHED' THEN
        SELECT id INTO v_event_id
        FROM integration.outbox_events
        WHERE event_type = 'catalog.release.published'
          AND (payload->>'release_id')::uuid = p_release_id
        ORDER BY created_at DESC LIMIT 1;

        RETURN jsonb_build_object(
            'published', true,
            'idempotent', true,
            'release_id', v_release.id,
            'version', v_release.version,
            'status', v_release.status,
            'sequence', v_release.release_sequence,
            'event_id', v_event_id
        );
    END IF;

    IF v_release.status != 'DRAFT' THEN
        RETURN jsonb_build_object('published', false, 'error', 'INVALID_STATUS', 'current_status', v_release.status);
    END IF;

    -- Validate Stale Baseline
    SELECT id INTO v_actual_baseline
    FROM catalog.catalog_releases
    WHERE status = 'PUBLISHED' AND id != p_release_id
    ORDER BY release_sequence DESC NULLS LAST
    LIMIT 1;

    IF COALESCE(v_actual_baseline, '00000000-0000-0000-0000-000000000000'::uuid) != COALESCE(p_expected_baseline, '00000000-0000-0000-0000-000000000000'::uuid) THEN
        RETURN jsonb_build_object(
            'published', false,
            'error', 'STALE_REVIEW',
            'detail', 'A newer publication changed the baseline. Refresh review before publishing.'
        );
    END IF;

    UPDATE catalog.catalog_releases SET status = 'PUBLISHED' WHERE id = p_release_id AND status = 'DRAFT'
    RETURNING release_sequence INTO v_release.release_sequence;
    
    SELECT id INTO v_event_id
    FROM integration.outbox_events
    WHERE event_type = 'catalog.release.published'
      AND (payload->>'release_id')::uuid = p_release_id
    ORDER BY created_at DESC LIMIT 1;

    RETURN jsonb_build_object(
        'published', true,
        'idempotent', false,
        'release_id', v_release.id,
        'version', v_release.version,
        'status', 'PUBLISHED',
        'sequence', v_release.release_sequence,
        'event_id', v_event_id
    );
END;
$fn$;
REVOKE ALL ON FUNCTION catalog.publish_draft_release(UUID, UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION catalog.publish_draft_release(UUID, UUID) TO service_role;
ALTER FUNCTION catalog.publish_draft_release(UUID, UUID) OWNER TO postgres;

-- 4. Update public wrapper
CREATE OR REPLACE FUNCTION public.publish_draft_release_wrapper(p_release_id UUID, p_expected_baseline UUID)
RETURNS JSONB
LANGUAGE sql
SECURITY DEFINER
SET search_path = catalog, pg_temp
AS $$
    SELECT catalog.publish_draft_release(p_release_id, p_expected_baseline);
$$;
REVOKE ALL ON FUNCTION public.publish_draft_release_wrapper(UUID, UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.publish_draft_release_wrapper(UUID, UUID) TO service_role;
ALTER FUNCTION public.publish_draft_release_wrapper(UUID, UUID) OWNER TO postgres;

COMMIT;
