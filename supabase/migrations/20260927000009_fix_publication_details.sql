-- Migration 20260927000009: Fix all five publication workflow details
-- Scope: GC database

BEGIN;
SET LOCAL search_path = '';

-- 1. Atomic create: detect cleanup mismatch
CREATE OR REPLACE FUNCTION catalog.create_business_release(p_version TEXT, p_include_cleanup BOOLEAN)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = catalog, public, pg_temp
AS $fn$
DECLARE
    v_release_id UUID;
    v_existing   RECORD;
    v_existing_cleanup BOOLEAN;
BEGIN
    -- Atomic loop for insert
    LOOP
        BEGIN
            v_release_id := gen_random_uuid();
            INSERT INTO catalog.catalog_releases 
                (id, version, status, hsn_sac_intentionally_empty, tax_profiles_intentionally_empty, units_intentionally_empty)
            VALUES 
                (v_release_id, p_version, 'DRAFT', false, false, false);
            
            EXIT; -- success
        EXCEPTION WHEN unique_violation THEN
            -- Check if it's the version key
            IF SQLERRM LIKE '%catalog_releases_version_key%' THEN
                SELECT id, status INTO v_existing
                FROM catalog.catalog_releases
                WHERE version = p_version;
                
                -- Detect if existing draft was cleanup: it would contain inactive non-business units
                SELECT EXISTS (
                    SELECT 1 FROM catalog.catalog_release_items 
                    WHERE release_id = v_existing.id AND item_type = 'UNIT' AND (payload->>'is_business')::boolean = false
                ) INTO v_existing_cleanup;

                IF v_existing_cleanup != p_include_cleanup THEN
                    RAISE EXCEPTION 'Incompatible reuse: existing draft has include_cleanup = %, requested = %', v_existing_cleanup, p_include_cleanup;
                END IF;

                RETURN jsonb_build_object(
                    'release_id', v_existing.id,
                    'created', false,
                    'status', v_existing.status
                );
            ELSE
                RAISE;
            END IF;
        END;
    END LOOP;

    -- 1. HSN_SAC
    INSERT INTO catalog.catalog_release_items (release_id, item_type, item_id, payload)
    SELECT v_release_id, 'HSN_SAC', id,
        jsonb_build_object(
            'id', id, 'code', code, 'type', goods_or_service,
            'description', description, 'category', COALESCE(chapter, heading)
        )
    FROM catalog.hsn_sac;

    -- 2. UNIT
    INSERT INTO catalog.catalog_release_items (release_id, item_type, item_id, payload)
    SELECT v_release_id, 'UNIT', id,
        jsonb_build_object(
            'id', id, 'code', COALESCE(standard_code, canonical_code),
            'canonical_code', canonical_code,
            'name', name,
            'is_business', is_business,
            'business_name', business_name,
            'short_name', short_name,
            'status', CASE WHEN is_business THEN status WHEN p_include_cleanup THEN 'INACTIVE' ELSE status END
        )
    FROM catalog.measurement_units
    WHERE is_business = true OR p_include_cleanup = true;

    -- 3. TAX_PROFILE
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
END;
$fn$;
ALTER FUNCTION catalog.create_business_release(TEXT, BOOLEAN) OWNER TO postgres;

-- 2. Retry-safe publish: serialize retries and return actual existing event/sequence
CREATE OR REPLACE FUNCTION catalog.publish_draft_release(p_release_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = catalog, integration, public, pg_temp
AS $fn$
DECLARE
    v_release RECORD;
    v_event_id UUID;
BEGIN
    -- Serialize concurrent publish calls on the same release ID
    SELECT id, status, version, release_sequence INTO v_release
    FROM catalog.catalog_releases
    WHERE id = p_release_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'published', false,
            'error', 'RELEASE_NOT_FOUND'
        );
    END IF;

    IF v_release.status = 'PUBLISHED' THEN
        -- Find existing event
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
        RETURN jsonb_build_object(
            'published', false,
            'error', 'INVALID_STATUS',
            'current_status', v_release.status
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
ALTER FUNCTION catalog.publish_draft_release(UUID) OWNER TO postgres;

-- 3. Correct Review RPC (prefilter, explicit baseline, correct payload release_id)
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

    -- Explicit baseline excluding self-comparison
    SELECT id, version, release_sequence
    INTO v_baseline
    FROM catalog.catalog_releases
    WHERE status = 'PUBLISHED' AND id != p_draft_id
    ORDER BY created_at DESC
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
        -- Prefilter baseline/draft items separately
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
        -- Match outbox payload.release_id
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

REVOKE ALL ON FUNCTION public.get_release_review(UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_release_review(UUID) TO service_role;
ALTER FUNCTION public.get_release_review(UUID) OWNER TO postgres;

-- Public wrappers ownership
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
ALTER FUNCTION public.create_business_release_wrapper(TEXT, BOOLEAN) OWNER TO postgres;

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
ALTER FUNCTION public.publish_draft_release_wrapper(UUID) OWNER TO postgres;

COMMIT;
