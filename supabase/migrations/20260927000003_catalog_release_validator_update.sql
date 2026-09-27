-- Forward Migration: Update payload validator and publisher for tax extension
-- File: 20260927000003_catalog_release_validator_update.sql
-- Scope: GC database
-- Purpose: 
-- 1. Extend fn_validate_release_items to permit the full gst_rate_master schema.
-- 2. Extend fn_publish_release to map these fields securely from the snapshotted payload.

BEGIN;
SET LOCAL search_path = '';

-- 1. Extend the validator
CREATE OR REPLACE FUNCTION catalog.fn_validate_release_items(p_release_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_item     RECORD;
    v_uuid_re  TEXT := '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$';
    v_rate     NUMERIC;
BEGIN
    FOR v_item IN
        SELECT item_type, item_id, payload
        FROM catalog.catalog_release_items
        WHERE release_id = p_release_id
    LOOP
        IF v_item.item_type NOT IN ('HSN_SAC', 'TAX_PROFILE', 'UNIT') THEN
            RAISE EXCEPTION 'MALFORMED_PAYLOAD: Unknown item_type %', v_item.item_type;
        END IF;

        IF (v_item.payload->>'id') IS NULL THEN
            RAISE EXCEPTION 'MALFORMED_PAYLOAD: item payload missing id field (type=%)', v_item.item_type;
        END IF;
        IF NOT (v_item.payload->>'id' ~ v_uuid_re) THEN
            RAISE EXCEPTION 'MALFORMED_PAYLOAD: item id is not a valid UUID (type=%)', v_item.item_type;
        END IF;
        IF v_item.item_id IS DISTINCT FROM (v_item.payload->>'id')::UUID THEN
            RAISE EXCEPTION 'MALFORMED_PAYLOAD: item_id does not match payload id (type=%)', v_item.item_type;
        END IF;

        IF v_item.item_type = 'HSN_SAC' THEN
            IF (v_item.payload->>'code') IS NULL THEN
                RAISE EXCEPTION 'MALFORMED_PAYLOAD: HSN_SAC item missing code';
            END IF;
            IF (v_item.payload->>'type') IS NULL THEN
                RAISE EXCEPTION 'MALFORMED_PAYLOAD: HSN_SAC item missing type';
            END IF;
            IF v_item.payload - ARRAY['id','code','type','description','category'] != '{}' THEN
                RAISE EXCEPTION 'MALFORMED_PAYLOAD: HSN_SAC item has unknown keys';
            END IF;

        ELSIF v_item.item_type = 'TAX_PROFILE' THEN
            IF (v_item.payload->>'name') IS NULL AND (v_item.payload->>'rate_name') IS NULL THEN
                RAISE EXCEPTION 'MALFORMED_PAYLOAD: TAX_PROFILE item missing name/rate_name';
            END IF;
            IF (v_item.payload->>'rate') IS NULL AND (v_item.payload->>'rate_percent') IS NULL THEN
                RAISE EXCEPTION 'MALFORMED_PAYLOAD: TAX_PROFILE item missing rate/rate_percent';
            END IF;
            
            IF v_item.payload - ARRAY[
                'id','name','rate','category','is_current',
                'country_id', 'rate_name', 'rate_percent', 'statutory_rate_percent',
                'effective_display_percent', 'erp_visibility', 'valuation_basis',
                'itc_policy', 'conditions', 'usage_scope', 'status',
                'effective_from', 'effective_to'
            ] != '{}' THEN
                RAISE EXCEPTION 'MALFORMED_PAYLOAD: TAX_PROFILE item has unknown keys';
            END IF;

        ELSIF v_item.item_type = 'UNIT' THEN
            IF (v_item.payload->>'name') IS NULL THEN
                RAISE EXCEPTION 'MALFORMED_PAYLOAD: UNIT item missing name';
            END IF;
            IF COALESCE(v_item.payload->>'canonical_code', v_item.payload->>'code') IS NULL THEN
                RAISE EXCEPTION 'MALFORMED_PAYLOAD: UNIT item missing code/canonical_code';
            END IF;
            IF v_item.payload - ARRAY['id','code','canonical_code','name','is_business', 'business_name', 'short_name', 'status'] != '{}' THEN
                RAISE EXCEPTION 'MALFORMED_PAYLOAD: UNIT item has unknown keys';
            END IF;
        END IF;
    END LOOP;
END;
$$;
REVOKE ALL ON FUNCTION catalog.fn_validate_release_items(UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION catalog.fn_validate_release_items(UUID) TO service_role;

-- 2. Update fn_publish_release to map the fields from the snapshotted payload (NO JOINs)
CREATE OR REPLACE FUNCTION catalog.fn_publish_release()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_seq             BIGINT;
    v_event_id        UUID;
    v_idempotency_key TEXT;
    v_raw_body        TEXT;
    v_hsn_count       BIGINT;
    v_tax_count       BIGINT;
    v_unit_count      BIGINT;
    v_recipient_count BIGINT;
BEGIN
    -- Only fire on DRAFT -> PUBLISHED transition
    IF NEW.status = 'PUBLISHED' AND OLD.status != 'PUBLISHED' THEN

        -- P06: Reject blank release version
        IF NEW.version IS NULL OR trim(NEW.version) = '' THEN
            RAISE EXCEPTION 'MALFORMED_PAYLOAD: release version cannot be blank';
        END IF;

        -- Count items by domain
        SELECT count(*) INTO v_hsn_count
            FROM catalog.catalog_release_items
            WHERE release_id = NEW.id AND item_type = 'HSN_SAC';

        SELECT count(*) INTO v_tax_count
            FROM catalog.catalog_release_items
            WHERE release_id = NEW.id AND item_type = 'TAX_PROFILE';

        SELECT count(*) INTO v_unit_count
            FROM catalog.catalog_release_items
            WHERE release_id = NEW.id AND item_type = 'UNIT';

        -- Validate intentional empty flags
        IF v_hsn_count = 0 AND NOT NEW.hsn_sac_intentionally_empty THEN
            RAISE EXCEPTION 'MALFORMED_PAYLOAD: hsn_sac is empty but hsn_sac_intentionally_empty is not TRUE';
        END IF;
        IF v_hsn_count > 0 AND NEW.hsn_sac_intentionally_empty THEN
            RAISE EXCEPTION 'MALFORMED_PAYLOAD: hsn_sac is populated but hsn_sac_intentionally_empty is TRUE';
        END IF;
        IF v_tax_count = 0 AND NOT NEW.tax_profiles_intentionally_empty THEN
            RAISE EXCEPTION 'MALFORMED_PAYLOAD: tax_profiles is empty but tax_profiles_intentionally_empty is not TRUE';
        END IF;
        IF v_tax_count > 0 AND NEW.tax_profiles_intentionally_empty THEN
            RAISE EXCEPTION 'MALFORMED_PAYLOAD: tax_profiles is populated but tax_profiles_intentionally_empty is TRUE';
        END IF;
        IF v_unit_count = 0 AND NOT NEW.units_intentionally_empty THEN
            RAISE EXCEPTION 'MALFORMED_PAYLOAD: units is empty but units_intentionally_empty is not TRUE';
        END IF;
        IF v_unit_count > 0 AND NEW.units_intentionally_empty THEN
            RAISE EXCEPTION 'MALFORMED_PAYLOAD: units is populated but units_intentionally_empty is TRUE';
        END IF;

        -- P06: Validate all items (including pre-existing DRAFT rows) BEFORE acquiring lock
        PERFORM catalog.fn_validate_release_items(NEW.id);

        -- P06: Lock publication serializer to prevent concurrent publication
        PERFORM 1 FROM catalog.catalog_sync_control WHERE contract_key = 'AGGREGATE_V1' FOR UPDATE;

        -- Allocate sequence inside the lock
        v_seq := pg_catalog.nextval('catalog.release_seq');

        -- Generate event_id BEFORE body construction
        v_event_id := pg_catalog.gen_random_uuid();

        -- Idempotency key per ADR #6
        v_idempotency_key := 'catalog.release.published:' || NEW.id::text;

        -- Build canonical payload
        SELECT pg_catalog.json_build_object(
            'event_id',   v_event_id,
            'release_id', NEW.id,
            'release_version', NEW.version,
            'release_sequence', v_seq,
            
            'hsn_sac', COALESCE((
                SELECT pg_catalog.json_agg(
                    pg_catalog.json_build_object(
                        'id',          item.payload->>'id',
                        'code',        item.payload->>'code',
                        'type',        item.payload->>'type',
                        'description', item.payload->>'description',
                        'category',    item.payload->>'category'
                    ) ORDER BY item.item_id ASC
                )
                FROM catalog.catalog_release_items item
                WHERE item.release_id = NEW.id AND item.item_type = 'HSN_SAC'
            ), '[]'::json),
            'hsn_sac_intentionally_empty', NEW.hsn_sac_intentionally_empty,
            
            'tax_profiles', COALESCE((
                SELECT pg_catalog.json_agg(
                    pg_catalog.json_build_object(
                        'id',                        item.payload->>'id',
                        'name',                      COALESCE(item.payload->>'rate_name', item.payload->>'name'),
                        'rate',                      COALESCE((item.payload->>'rate_percent')::NUMERIC(5,2), (item.payload->>'rate')::NUMERIC(5,2)),
                        'country_id',                item.payload->>'country_id',
                        'rate_name',                 item.payload->>'rate_name',
                        'rate_percent',              (item.payload->>'rate_percent')::NUMERIC(5,2),
                        'category',                  item.payload->>'category',
                        'statutory_rate_percent',    (item.payload->>'statutory_rate_percent')::NUMERIC(5,2),
                        'effective_display_percent', (item.payload->>'effective_display_percent')::NUMERIC(5,2),
                        'erp_visibility',            item.payload->>'erp_visibility',
                        'valuation_basis',           item.payload->>'valuation_basis',
                        'itc_policy',                item.payload->>'itc_policy',
                        'conditions',                item.payload->'conditions',
                        'usage_scope',               item.payload->>'usage_scope',
                        'is_current',                COALESCE((item.payload->>'is_current')::BOOLEAN, TRUE),
                        'status',                    item.payload->>'status',
                        'effective_from',            item.payload->>'effective_from',
                        'effective_to',              item.payload->>'effective_to'
                    ) ORDER BY item.item_id ASC
                )
                FROM catalog.catalog_release_items item
                WHERE item.release_id = NEW.id AND item.item_type = 'TAX_PROFILE'
            ), '[]'::json),
            'tax_profiles_intentionally_empty', NEW.tax_profiles_intentionally_empty,
            
            'units', COALESCE((
                SELECT pg_catalog.json_agg(
                    pg_catalog.json_build_object(
                        'id',             item.payload->>'id',
                        'code',           COALESCE(item.payload->>'canonical_code', item.payload->>'code'),
                        'canonical_code', item.payload->>'canonical_code',
                        'name',           item.payload->>'name',
                        'business_name',  item.payload->>'business_name',
                        'short_name',     item.payload->>'short_name',
                        'is_business',    COALESCE((item.payload->>'is_business')::BOOLEAN, FALSE),
                        'status',         item.payload->>'status'
                    ) ORDER BY item.item_id ASC
                )
                FROM catalog.catalog_release_items item
                WHERE item.release_id = NEW.id AND item.item_type = 'UNIT'
            ), '[]'::json),
            'units_intentionally_empty', NEW.units_intentionally_empty
        )::TEXT INTO v_raw_body;

        -- Set publication metadata on the row being updated
        NEW.release_sequence := v_seq;
        NEW.published_at := pg_catalog.now();

        -- Insert outbox event
        INSERT INTO integration.outbox_events
            (id, event_type, idempotency_key, payload, raw_body, created_at)
        VALUES
            (v_event_id, 'catalog.release.published', v_idempotency_key, v_raw_body::jsonb, v_raw_body, pg_catalog.now());

        -- P05: Snapshot delivery state atomically using live endpoint values AT PUBLICATION TIME
        WITH inserted_recipients AS (
            INSERT INTO integration.delivery_state
                (event_id, endpoint_id, endpoint_url, secret, recipient_identity, status, next_attempt_at)
            SELECT
                v_event_id,
                we.id,
                we.url,
                we.secret,
                COALESCE(we.description, we.id::TEXT),
                'PENDING',
                pg_catalog.now()
            FROM integration.topic_subscriptions ts
            JOIN integration.webhook_endpoints we ON we.id = ts.endpoint_id
            WHERE ts.topic = 'catalog.release.published'
              AND ts.status = 'ACTIVE'
              AND we.status = 'ACTIVE'
            RETURNING endpoint_id
        )
        SELECT count(*) INTO v_recipient_count FROM inserted_recipients;

        IF v_recipient_count = 0 THEN
            RAISE EXCEPTION 'PUBLICATION_REJECTED: No eligible recipients subscribed to catalog.release.published';
        END IF;

    ELSIF OLD.status = 'PUBLISHED' THEN
        -- P06: Reject state regressions from PUBLISHED
        RAISE EXCEPTION 'ILLEGAL_STATE_TRANSITION: Cannot modify or revert a PUBLISHED release';
    END IF;

    RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION catalog.fn_publish_release() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION catalog.fn_publish_release() TO service_role;

COMMIT;
