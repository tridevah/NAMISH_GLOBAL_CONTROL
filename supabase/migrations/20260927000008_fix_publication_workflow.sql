-- Migration 20260927000008: Fix all five publication workflow defects
-- Scope: GC database

BEGIN;
SET LOCAL search_path = '';

-- Drop and recreate functions that change return type
DROP FUNCTION IF EXISTS catalog.create_business_release(text, boolean);
DROP FUNCTION IF EXISTS catalog.publish_draft_release(uuid);
DROP FUNCTION IF EXISTS public.create_business_release_wrapper(text, boolean);
DROP FUNCTION IF EXISTS public.publish_draft_release_wrapper(uuid);
DROP FUNCTION IF EXISTS public.get_release_review(uuid);

CREATE OR REPLACE FUNCTION catalog.create_business_release(p_version TEXT, p_include_cleanup BOOLEAN)
RETURNS JSONB  -- changed to JSONB to return both release_id and created/existing status
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = catalog, public, pg_temp
AS $fn$
DECLARE
    v_release_id UUID;
    v_existing   RECORD;
BEGIN
    -- Atomic: on concurrent version collision, return existing id
    SELECT id, status INTO v_existing
    FROM catalog.catalog_releases
    WHERE version = p_version;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'release_id', v_existing.id,
            'created', false,
            'status', v_existing.status
        );
    END IF;

    v_release_id := gen_random_uuid();

    INSERT INTO catalog.catalog_releases
        (id, version, status, hsn_sac_intentionally_empty, tax_profiles_intentionally_empty, units_intentionally_empty)
    VALUES
        (v_release_id, p_version, 'DRAFT', false, false, false);

    -- 1. HSN_SAC
    INSERT INTO catalog.catalog_release_items (release_id, item_type, item_id, payload)
    SELECT v_release_id, 'HSN_SAC', id,
        jsonb_build_object(
            'id', id, 'code', code, 'type', goods_or_service,
            'description', description, 'category', COALESCE(chapter, heading)
        )
    FROM catalog.hsn_sac;

    -- 2. UNIT — non-business units NOT forced ACTIVE; their own status preserved
    INSERT INTO catalog.catalog_release_items (release_id, item_type, item_id, payload)
    SELECT v_release_id, 'UNIT', id,
        jsonb_build_object(
            'id', id, 'code', COALESCE(standard_code, canonical_code),
            'canonical_code', canonical_code,
            'name', name,
            'is_business', is_business,
            'business_name', business_name,
            'short_name', short_name,
            -- Preserve source status for business units; explicitly INACTIVE for non-business in cleanup pass
            'status', CASE
                WHEN is_business THEN status
                WHEN p_include_cleanup THEN 'INACTIVE'
                ELSE status
            END
        )
    FROM catalog.measurement_units
    WHERE is_business = true OR p_include_cleanup = true;

    -- 3. TAX_PROFILE (from public.gst_rate_master per verified contract)
    INSERT INTO catalog.catalog_release_items (release_id, item_type, item_id, payload)
    SELECT v_release_id, 'TAX_PROFILE', id,
        jsonb_build_object(
            'id', id, 'country_id', country_id,
            'name', rate_name, 'rate', rate_percent,
            'category', category,
            'statutory_rate_percent', statutory_rate_percent,
            'effective_display_percent', effective_display_percent,
            'erp_visibility', erp_visibility, 'valuation_basis', valuation_basis,
            'itc_policy', itc_policy, 'conditions', COALESCE(conditions, '{}'::jsonb),
            'usage_scope', usage_scope, 'status', status,
            'effective_from', effective_from, 'effective_to', effective_to,
            'is_current', is_current
        )
    FROM public.gst_rate_master;

    RETURN jsonb_build_object(
        'release_id', v_release_id,
        'created', true,
        'status', 'DRAFT'
    );
EXCEPTION WHEN unique_violation THEN
    -- Concurrent insert won the race; look up the winner and return it
    SELECT id, status INTO v_existing
    FROM catalog.catalog_releases
    WHERE version = p_version;

    RETURN jsonb_build_object(
        'release_id', v_existing.id,
        'created', false,
        'status', v_existing.status
    );
END;
$fn$;

-- ─── FIX 2: Retry-safe publish — return existing publication identity, never error ─

CREATE OR REPLACE FUNCTION catalog.publish_draft_release(p_release_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = catalog, pg_temp
AS $fn$
DECLARE
    v_release RECORD;
BEGIN
    SELECT id, status, version INTO v_release
    FROM catalog.catalog_releases
    WHERE id = p_release_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'published', false,
            'error', 'RELEASE_NOT_FOUND'
        );
    END IF;

    -- Already published: return existing identity (idempotent retry)
    IF v_release.status = 'PUBLISHED' THEN
        RETURN jsonb_build_object(
            'published', true,
            'idempotent', true,
            'release_id', v_release.id,
            'version', v_release.version,
            'status', v_release.status
        );
    END IF;

    IF v_release.status != 'DRAFT' THEN
        RETURN jsonb_build_object(
            'published', false,
            'error', 'INVALID_STATUS',
            'current_status', v_release.status
        );
    END IF;

    UPDATE catalog.catalog_releases SET status = 'PUBLISHED' WHERE id = p_release_id AND status = 'DRAFT';

    RETURN jsonb_build_object(
        'published', true,
        'idempotent', false,
        'release_id', v_release.id,
        'version', v_release.version,
        'status', 'PUBLISHED'
    );
END;
$fn$;

-- Update public wrappers to pass through JSONB
CREATE OR REPLACE FUNCTION public.create_business_release_wrapper(p_version TEXT, p_include_cleanup BOOLEAN)
RETURNS JSONB
LANGUAGE sql
SECURITY DEFINER
SET search_path = catalog, pg_temp
AS $$
    SELECT catalog.create_business_release(p_version, p_include_cleanup);
$$;
REVOKE ALL ON FUNCTION public.create_business_release_wrapper(TEXT, BOOLEAN) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.create_business_release_wrapper(TEXT, BOOLEAN) TO service_role;

CREATE OR REPLACE FUNCTION public.publish_draft_release_wrapper(p_release_id UUID)
RETURNS JSONB
LANGUAGE sql
SECURITY DEFINER
SET search_path = catalog, pg_temp
AS $$
    SELECT catalog.publish_draft_release(p_release_id);
$$;
REVOKE ALL ON FUNCTION public.publish_draft_release_wrapper(UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.publish_draft_release_wrapper(UUID) TO service_role;

-- ─── FIX 3, 4, 5: Correct review RPC using actual integration schema ────────────

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
    -- Draft info
    SELECT id, version, status
    INTO v_draft
    FROM catalog.catalog_releases
    WHERE id = p_draft_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('error', 'DRAFT_NOT_FOUND');
    END IF;

    -- Most-recent published baseline (for comparison)
    SELECT id, version, release_sequence
    INTO v_baseline
    FROM catalog.catalog_releases
    WHERE status = 'PUBLISHED'
    ORDER BY created_at DESC
    LIMIT 1;

    -- Item counts for the draft
    SELECT jsonb_object_agg(item_type, cnt)
    INTO v_counts
    FROM (
        SELECT item_type, count(*) AS cnt
        FROM catalog.catalog_release_items
        WHERE release_id = p_draft_id
        GROUP BY item_type
    ) t;

    -- Diff vs baseline (by canonical item_type/item_id and payload equality)
    IF v_baseline.id IS NOT NULL THEN
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
            FROM catalog.catalog_release_items p
            FULL OUTER JOIN catalog.catalog_release_items d
                ON p.item_type = d.item_type AND p.item_id = d.item_id
               AND d.release_id = p_draft_id
            WHERE p.release_id = v_baseline.id
            GROUP BY COALESCE(p.item_type, d.item_type)
        ) diff_t;
    END IF;

    -- Delivery status for PUBLISHED releases:
    -- Resolve event by event_type = 'catalog.release.published' AND payload->>'id' = release_id
    -- Then resolve delivery per endpoint in delivery_state
    IF v_draft.status = 'PUBLISHED' THEN
        SELECT e.id, e.status AS event_status
        INTO v_event
        FROM integration.outbox_events e
        WHERE e.event_type = 'catalog.release.published'
          AND (e.payload->>'id')::uuid = p_draft_id
        ORDER BY e.created_at DESC
        LIMIT 1;

        IF NOT FOUND THEN
            v_delivery := jsonb_build_object(
                'lookup_status', 'EVENT_NOT_FOUND',
                'detail', 'No outbox event matched event_type=catalog.release.published and payload.id=' || p_draft_id::text
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
        -- Draft: show which subscriptions would receive it on publication
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

REVOKE ALL ON FUNCTION public.get_release_review(UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_release_review(UUID) TO service_role;
ALTER FUNCTION public.get_release_review(UUID) OWNER TO postgres;

COMMIT;
