-- Migration 20260928000011: Fix lock order and UI issues
-- Scope: GC database

BEGIN;

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
    -- 1. Acquire the existing AGGREGATE_V1 publisher serialization lock before checking the expected baseline.
    -- This enforces a consistent lock order: catalog_sync_control -> catalog_releases
    PERFORM 1 FROM catalog.catalog_sync_control WHERE contract_key = 'AGGREGATE_V1' FOR UPDATE;

    -- 2. Lock the specific release record
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

    -- Validate Stale Baseline under the global lock
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

COMMIT;
