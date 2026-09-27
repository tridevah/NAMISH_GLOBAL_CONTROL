-- GC Catalog Sync Bootstrap (V2R2 Phase 2 FIXED)
-- TEST_ONLY seed: 1 (local offline fixture; NOT production-authorized)
-- Production seed requires separate authorized observation and approval
-- P01: This file adds only new sync objects; historical migrations are untouched.
-- DO NOT alter this migration. Deploy as-is from the approved package.

BEGIN;
SET LOCAL search_path = '';

-- ── PREFLIGHT: Fail closed on partial/unknown deployment ─────────────────────
DO $$
DECLARE
    v_has_control  BOOLEAN;
    v_has_seq      BOOLEAN;
    v_has_ds       BOOLEAN;
    v_has_rel_seq  BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM pg_catalog.pg_class c
        JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'catalog' AND c.relname = 'catalog_sync_control'
    ) INTO v_has_control;

    SELECT EXISTS (
        SELECT 1 FROM pg_catalog.pg_class c
        JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'catalog' AND c.relname = 'release_seq'
          AND c.relkind = 'S'
    ) INTO v_has_seq;

    SELECT EXISTS (
        SELECT 1 FROM pg_catalog.pg_class c
        JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'integration' AND c.relname = 'delivery_state'
    ) INTO v_has_ds;

    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'catalog'
          AND table_name = 'catalog_releases'
          AND column_name = 'release_sequence'
    ) INTO v_has_rel_seq;

    IF v_has_control OR v_has_seq OR v_has_ds OR v_has_rel_seq THEN
        IF v_has_control AND v_has_seq AND v_has_ds AND v_has_rel_seq THEN
            RAISE EXCEPTION 'STOP: Catalog sync is already fully deployed. Do not re-apply.';
        ELSE
            RAISE EXCEPTION 'STOP: Partial deployment detected. Manual remediation required before proceeding.';
        END IF;
    END IF;
END;
$$;

-- ── 1. Global release sequence ───────────────────────────────────────────────
-- P10: Seed is TEST_ONLY; production requires authorized seed approval
CREATE SEQUENCE catalog.release_seq
    START WITH 1
    INCREMENT BY 1
    MINVALUE 1
    MAXVALUE 9007199254740991
    NO CYCLE
    CACHE 1;
REVOKE ALL ON SEQUENCE catalog.release_seq FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SEQUENCE catalog.release_seq TO service_role;

-- ── 2. Catalog sync control (immutable singleton) ────────────────────────────
CREATE TABLE catalog.catalog_sync_control (
    contract_key     TEXT NOT NULL PRIMARY KEY CHECK (contract_key = 'AGGREGATE_V1'),
    cutover_at       TIMESTAMPTZ NOT NULL,
    initial_sequence BIGINT NOT NULL
                         -- P07c: positive and JS-safe bound
                         CHECK (initial_sequence >= 1 AND initial_sequence <= 9007199254740991),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now()
);
REVOKE ALL ON TABLE catalog.catalog_sync_control FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE catalog.catalog_sync_control TO service_role;

INSERT INTO catalog.catalog_sync_control (contract_key, cutover_at, initial_sequence)
VALUES ('AGGREGATE_V1', pg_catalog.now(), 1);

-- Immutability trigger function
CREATE OR REPLACE FUNCTION catalog.fn_prevent_sync_control_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    RAISE EXCEPTION 'catalog_sync_control is immutable after deployment';
    RETURN NULL;
END;
$$;

-- P07d: TRUNCATE protection (statement-level)
CREATE TRIGGER trg_sync_control_immutable
BEFORE UPDATE OR DELETE ON catalog.catalog_sync_control
FOR EACH ROW EXECUTE FUNCTION catalog.fn_prevent_sync_control_mutation();

CREATE TRIGGER trg_sync_control_no_truncate
BEFORE TRUNCATE ON catalog.catalog_sync_control
EXECUTE FUNCTION catalog.fn_prevent_sync_control_mutation();

-- ── 3. Extend catalog_releases ───────────────────────────────────────────────
ALTER TABLE catalog.catalog_releases
    ADD COLUMN release_sequence          BIGINT,
    ADD COLUMN hsn_sac_intentionally_empty   BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN tax_profiles_intentionally_empty BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN units_intentionally_empty     BOOLEAN NOT NULL DEFAULT FALSE;

CREATE UNIQUE INDEX uq_catalog_releases_release_seq
    ON catalog.catalog_releases (release_sequence)
    WHERE release_sequence IS NOT NULL;

-- ── 4. Extend outbox_events with raw_body ────────────────────────────────────
ALTER TABLE integration.outbox_events
    ADD COLUMN raw_body TEXT NOT NULL DEFAULT '';

-- P07a: Immutability trigger covers raw_body AND event identity/payload
CREATE OR REPLACE FUNCTION integration.fn_prevent_outbox_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    -- raw_body is immutable
    IF NEW.raw_body IS DISTINCT FROM OLD.raw_body THEN
        RAISE EXCEPTION 'integration.outbox_events.raw_body is immutable after insert';
    END IF;
    -- event identity is immutable
    IF NEW.event_type IS DISTINCT FROM OLD.event_type THEN
        RAISE EXCEPTION 'integration.outbox_events.event_type is immutable after insert';
    END IF;
    -- idempotency_key is immutable
    IF NEW.idempotency_key IS DISTINCT FROM OLD.idempotency_key THEN
        RAISE EXCEPTION 'integration.outbox_events.idempotency_key is immutable after insert';
    END IF;
    -- payload is immutable
    IF NEW.payload IS DISTINCT FROM OLD.payload THEN
        RAISE EXCEPTION 'integration.outbox_events.payload is immutable after insert';
    END IF;
    -- status transitions ARE permitted (PENDING -> SUCCESS/DEAD)
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_outbox_immutable
BEFORE UPDATE ON integration.outbox_events
FOR EACH ROW EXECUTE FUNCTION integration.fn_prevent_outbox_mutation();

-- P07d: TRUNCATE protection on outbox_events
CREATE OR REPLACE FUNCTION integration.fn_prevent_outbox_truncate()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    RAISE EXCEPTION 'integration.outbox_events does not permit TRUNCATE';
    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_outbox_no_truncate
BEFORE TRUNCATE ON integration.outbox_events
EXECUTE FUNCTION integration.fn_prevent_outbox_truncate();

-- ── 5. Topic subscriptions ───────────────────────────────────────────────────
CREATE TABLE integration.topic_subscriptions (
    id          UUID NOT NULL PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
    endpoint_id UUID NOT NULL REFERENCES integration.webhook_endpoints(id),
    topic       TEXT NOT NULL,
    status      TEXT NOT NULL DEFAULT 'ACTIVE'
                    CHECK (status IN ('ACTIVE', 'PAUSED', 'DRAINING')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now(),
    UNIQUE (endpoint_id, topic)
);
REVOKE ALL ON TABLE integration.topic_subscriptions FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE integration.topic_subscriptions TO service_role;

-- ── 6. Delivery state ────────────────────────────────────────────────────────
CREATE TABLE integration.delivery_state (
    event_id           UUID NOT NULL REFERENCES integration.outbox_events(id),
    endpoint_id        UUID NOT NULL,
    -- P05: Snapshot fields captured at publication time; never re-read from live endpoint
    endpoint_url       TEXT NOT NULL,
    secret             TEXT NOT NULL,
    recipient_identity TEXT NOT NULL,
    status             TEXT NOT NULL DEFAULT 'PENDING'
                           CHECK (status IN ('PENDING', 'CLAIMED', 'SUCCESS', 'DEAD')),
    attempt_count      INT  NOT NULL DEFAULT 0 CHECK (attempt_count <= 5),
    next_attempt_at    TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now(),
    locked_until       TIMESTAMPTZ,
    lease_token        UUID,
    PRIMARY KEY (event_id, endpoint_id)
);
REVOKE ALL ON TABLE integration.delivery_state FROM PUBLIC, anon, authenticated;

-- ── 7. Handle existing delivery_attempts ─────────────────────────────────────
-- P07b: Verify exact shape (not just event_id presence) before dropping
DO $$
DECLARE
    v_row_count    BIGINT;
    v_has_old      BOOLEAN;
    v_shape_ok     BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM pg_catalog.pg_class c
        JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'integration' AND c.relname = 'delivery_attempts'
    ) INTO v_has_old;

    IF v_has_old THEN
        SELECT count(*) INTO v_row_count FROM integration.delivery_attempts;
        IF v_row_count > 0 THEN
            RAISE EXCEPTION 'STOP: integration.delivery_attempts has % rows. Cannot replace non-empty legacy table.', v_row_count;
        END IF;

        -- Verify key columns exist (id, event_id, endpoint_id, status)
        SELECT (
            count(*) FILTER (WHERE column_name = 'id') > 0 AND
            count(*) FILTER (WHERE column_name = 'event_id') > 0 AND
            count(*) FILTER (WHERE column_name = 'endpoint_id') > 0 AND
            count(*) FILTER (WHERE column_name = 'status') > 0
        ) INTO v_shape_ok
        FROM information_schema.columns
        WHERE table_schema = 'integration' AND table_name = 'delivery_attempts';

        IF NOT v_shape_ok THEN
            RAISE EXCEPTION 'STOP: integration.delivery_attempts shape verification failed; expected id, event_id, endpoint_id, status columns.';
        END IF;

        DROP TABLE integration.delivery_attempts;
    END IF;
END;
$$;

-- Create canonical delivery_attempts
CREATE TABLE integration.delivery_attempts (
    id             UUID NOT NULL PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
    event_id       UUID NOT NULL,
    endpoint_id    UUID NOT NULL,
    attempt_number INT  NOT NULL,
    http_status    INT,
    response_body  TEXT,
    execution_ms   INT,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now(),
    FOREIGN KEY (event_id, endpoint_id) REFERENCES integration.delivery_state(event_id, endpoint_id),
    UNIQUE(event_id, endpoint_id, attempt_number)
);
REVOKE ALL ON TABLE integration.delivery_attempts FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION integration.fn_prevent_attempts_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    RAISE EXCEPTION 'integration.delivery_attempts is immutable (append-only)';
    RETURN NULL;
END;
$$;

-- P07: Cover UPDATE and DELETE; history rows are append-only
CREATE TRIGGER trg_delivery_attempts_immutable
BEFORE UPDATE OR DELETE ON integration.delivery_attempts
FOR EACH ROW EXECUTE FUNCTION integration.fn_prevent_attempts_mutation();

-- ── 8. Payload validation function ───────────────────────────────────────────
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

        -- P06: null-safe id check; payload id must equal item_id
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
            IF (v_item.payload->>'name') IS NULL THEN
                RAISE EXCEPTION 'MALFORMED_PAYLOAD: TAX_PROFILE item missing name';
            END IF;
            IF (v_item.payload->>'rate') IS NULL THEN
                RAISE EXCEPTION 'MALFORMED_PAYLOAD: TAX_PROFILE item missing rate';
            END IF;
            BEGIN
                v_rate := (v_item.payload->>'rate')::NUMERIC(5,2);
            EXCEPTION WHEN others THEN
                RAISE EXCEPTION 'MALFORMED_PAYLOAD: TAX_PROFILE rate is not valid NUMERIC(5,2)';
            END;
            IF v_rate < 0 OR v_rate > 999.99 THEN
                RAISE EXCEPTION 'MALFORMED_PAYLOAD: TAX_PROFILE rate out of bounds';
            END IF;
            IF v_item.payload - ARRAY['id','name','rate','category','is_current'] != '{}' THEN
                RAISE EXCEPTION 'MALFORMED_PAYLOAD: TAX_PROFILE item has unknown keys';
            END IF;

        ELSIF v_item.item_type = 'UNIT' THEN
            IF (v_item.payload->>'name') IS NULL THEN
                RAISE EXCEPTION 'MALFORMED_PAYLOAD: UNIT item missing name';
            END IF;
            IF COALESCE(v_item.payload->>'canonical_code', v_item.payload->>'code') IS NULL THEN
                RAISE EXCEPTION 'MALFORMED_PAYLOAD: UNIT item missing code/canonical_code';
            END IF;
            IF v_item.payload - ARRAY['id','code','canonical_code','name','is_business'] != '{}' THEN
                RAISE EXCEPTION 'MALFORMED_PAYLOAD: UNIT item has unknown keys';
            END IF;
        END IF;
    END LOOP;

    -- Duplicate item_id check per domain
    IF EXISTS (
        SELECT item_id, item_type FROM catalog.catalog_release_items
        WHERE release_id = p_release_id
        GROUP BY item_id, item_type HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION 'MALFORMED_PAYLOAD: Duplicate item_id within same domain in release';
    END IF;
END;
$$;

-- ── 9. Publication trigger function ──────────────────────────────────────────
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
        -- and serialize with item writes that also acquire this lock
        PERFORM 1 FROM catalog.catalog_sync_control WHERE contract_key = 'AGGREGATE_V1' FOR UPDATE;

        -- Allocate sequence inside the lock
        v_seq := pg_catalog.nextval('catalog.release_seq');

        -- Generate event_id BEFORE body construction
        v_event_id := pg_catalog.gen_random_uuid();

        -- Idempotency key per ADR #6
        v_idempotency_key := 'catalog.release.published:' || NEW.id::text;

        -- Build canonical payload (exact key order per PAYLOAD_MAPPING_AND_CANONICAL_BYTES.md)
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
                        'id',         item.payload->>'id',
                        'name',       item.payload->>'name',
                        'rate',       (item.payload->>'rate')::NUMERIC(5,2),
                        'category',   item.payload->>'category',
                        'is_current', COALESCE((item.payload->>'is_current')::BOOLEAN, TRUE)
                    ) ORDER BY item.item_id ASC
                )
                FROM catalog.catalog_release_items item
                WHERE item.release_id = NEW.id AND item.item_type = 'TAX_PROFILE'
            ), '[]'::json),
            'tax_profiles_intentionally_empty', NEW.tax_profiles_intentionally_empty,
            'units', COALESCE((
                SELECT pg_catalog.json_agg(
                    pg_catalog.json_build_object(
                        'id',            item.payload->>'id',
                        'code',          COALESCE(item.payload->>'canonical_code', item.payload->>'code'),
                        'canonical_code', item.payload->>'canonical_code',
                        'name',          item.payload->>'name',
                        'is_business',   COALESCE((item.payload->>'is_business')::BOOLEAN, FALSE)
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
        -- These snapshot values (endpoint_url, secret, recipient_identity) are frozen in
        -- delivery_state and returned by claim_delivery; live endpoint edits cannot reroute.
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
        RAISE EXCEPTION 'Cannot modify a PUBLISHED release';
    END IF;

    RETURN NEW;
END;
$$;

-- Block direct INSERT as PUBLISHED
CREATE OR REPLACE FUNCTION catalog.fn_block_direct_published_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF NEW.status = 'PUBLISHED' THEN
        RAISE EXCEPTION 'Cannot INSERT a release directly as PUBLISHED. Use UPDATE transition.';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_block_published_insert
BEFORE INSERT ON catalog.catalog_releases
FOR EACH ROW EXECUTE FUNCTION catalog.fn_block_direct_published_insert();

CREATE TRIGGER trg_publish_release
BEFORE UPDATE ON catalog.catalog_releases
FOR EACH ROW EXECUTE FUNCTION catalog.fn_publish_release();

-- ── 9.5 Item immutability and serialization (P06) ─────────────────────────
-- P06: Lock parent regardless of status to serialize with publication
CREATE OR REPLACE FUNCTION catalog.fn_protect_published_items()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_parent_status TEXT;
BEGIN
    -- P06: Lock parent row regardless of status (serializes with publication)
    IF TG_OP IN ('UPDATE', 'DELETE') THEN
        PERFORM 1 FROM catalog.catalog_releases WHERE id = OLD.release_id FOR SHARE;
        SELECT status INTO v_parent_status FROM catalog.catalog_releases WHERE id = OLD.release_id;
        IF v_parent_status = 'PUBLISHED' THEN
            RAISE EXCEPTION 'Cannot modify items of a PUBLISHED release';
        END IF;
    END IF;
    IF TG_OP IN ('INSERT', 'UPDATE') THEN
        PERFORM 1 FROM catalog.catalog_releases WHERE id = NEW.release_id FOR SHARE;
        SELECT status INTO v_parent_status FROM catalog.catalog_releases WHERE id = NEW.release_id;
        IF v_parent_status = 'PUBLISHED' THEN
            RAISE EXCEPTION 'Cannot insert or update items of a PUBLISHED release';
        END IF;
        -- P06: null-safe payload id check
        IF NEW.payload->>'id' IS NULL THEN
            RAISE EXCEPTION 'MALFORMED_PAYLOAD: item payload missing id field';
        END IF;
        IF NEW.item_id IS DISTINCT FROM (NEW.payload->>'id')::UUID THEN
            RAISE EXCEPTION 'MALFORMED_PAYLOAD: item_id must equal payload id';
        END IF;
    END IF;
    IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_protect_published_items
BEFORE INSERT OR UPDATE OR DELETE ON catalog.catalog_release_items
FOR EACH ROW EXECUTE FUNCTION catalog.fn_protect_published_items();

-- ── 10. Dispatcher worker role ────────────────────────────────────────────────
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'gc_dispatcher_worker') THEN
        CREATE ROLE gc_dispatcher_worker NOLOGIN;
    ELSE
        RAISE EXCEPTION 'MIGRATION_BLOCKED: Role gc_dispatcher_worker already exists.';
    END IF;
END;
$$;

REVOKE ALL ON TABLE integration.outbox_events FROM gc_dispatcher_worker;
REVOKE ALL ON TABLE integration.delivery_state FROM gc_dispatcher_worker;
REVOKE ALL ON TABLE integration.delivery_attempts FROM gc_dispatcher_worker;
GRANT USAGE ON SCHEMA integration TO gc_dispatcher_worker;

-- ── 10.5 Outbox Aggregation ───────────────────────────────────────────────────
-- P07f: Restrict to gc_dispatcher_worker; called only from finalize_delivery (SECURITY DEFINER)
CREATE OR REPLACE FUNCTION integration.aggregate_outbox_status(p_event_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_total   INT;
    v_success INT;
    v_dead    INT;
BEGIN
    -- Take a lock on the outbox event row first to serialize concurrent finalizations
    PERFORM 1 FROM integration.outbox_events WHERE id = p_event_id FOR UPDATE;

    SELECT count(*),
           sum(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END),
           sum(CASE WHEN status = 'DEAD'    THEN 1 ELSE 0 END)
    INTO v_total, v_success, v_dead
    FROM integration.delivery_state
    WHERE event_id = p_event_id;

    IF v_total > 0 THEN
        IF v_success = v_total THEN
            UPDATE integration.outbox_events SET status = 'SUCCESS' WHERE id = p_event_id;
        ELSIF v_dead > 0 AND (v_success + v_dead = v_total) THEN
            UPDATE integration.outbox_events SET status = 'DEAD' WHERE id = p_event_id;
        ELSE
            UPDATE integration.outbox_events SET status = 'PENDING' WHERE id = p_event_id;
        END IF;
    END IF;
END;
$$;

-- P07f: Restrict aggregate helper; only callable from within finalize_delivery (SECURITY DEFINER)
REVOKE ALL ON FUNCTION integration.aggregate_outbox_status(UUID) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION integration.aggregate_outbox_status(UUID) TO gc_dispatcher_worker;

-- ── 11. claim_delivery RPC ─────────────────────────────────────────────────────
-- P04: Qualify all UPDATE predicates with table alias to avoid PL/pgSQL RETURNS TABLE ambiguity
-- P05: Return snapshot fields from delivery_state (not live endpoint values)

CREATE OR REPLACE FUNCTION integration.claim_delivery(p_limit INT)
RETURNS TABLE (
    event_id        UUID,
    endpoint_id     UUID,
    lease_token     UUID,
    endpoint_url    TEXT,
    secret          TEXT,
    recipient_identity TEXT,
    raw_body        TEXT,
    attempt_count   INT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_now    TIMESTAMPTZ := pg_catalog.now();
    v_swept  RECORD;
BEGIN
    IF p_limit IS NULL OR p_limit <= 0 OR p_limit > 100 THEN
        RAISE EXCEPTION 'claim_delivery: p_limit must be between 1 and 100';
    END IF;

    -- Sweep expired crashed deliveries (P04: qualify with alias to avoid RETURNS TABLE conflict)
    FOR v_swept IN
        SELECT ds.event_id AS swp_event_id,
               ds.endpoint_id AS swp_endpoint_id,
               ds.attempt_count AS swp_attempt_count
        FROM integration.delivery_state ds
        WHERE ds.status = 'CLAIMED' AND ds.locked_until < v_now
        FOR UPDATE OF ds SKIP LOCKED
    LOOP
        INSERT INTO integration.delivery_attempts
            (event_id, endpoint_id, attempt_number, http_status, response_body, execution_ms)
        VALUES (v_swept.swp_event_id, v_swept.swp_endpoint_id, v_swept.swp_attempt_count,
                0, 'WORKER_CRASH_OR_TIMEOUT', 0)
        ON CONFLICT DO NOTHING;

        -- P04: Use explicit table alias in UPDATE to avoid PL/pgSQL output-column ambiguity
        IF v_swept.swp_attempt_count >= 5 THEN
            UPDATE integration.delivery_state ds2
            SET status = 'DEAD', lease_token = NULL, locked_until = NULL
            WHERE ds2.event_id = v_swept.swp_event_id
              AND ds2.endpoint_id = v_swept.swp_endpoint_id;
            PERFORM integration.aggregate_outbox_status(v_swept.swp_event_id);
        ELSE
            UPDATE integration.delivery_state ds2
            SET status = 'PENDING', lease_token = NULL, locked_until = NULL
            WHERE ds2.event_id = v_swept.swp_event_id
              AND ds2.endpoint_id = v_swept.swp_endpoint_id;
        END IF;
    END LOOP;

    RETURN QUERY
    WITH
    eligible AS (
        SELECT ds.event_id AS elig_event_id, ds.endpoint_id AS elig_endpoint_id
        FROM integration.delivery_state ds
        JOIN integration.topic_subscriptions ts ON ts.endpoint_id = ds.endpoint_id
        JOIN integration.webhook_endpoints we ON we.id = ds.endpoint_id
        WHERE ds.status IN ('PENDING', 'CLAIMED')
          AND (ds.status = 'PENDING' OR ds.locked_until < v_now)
          AND ds.next_attempt_at <= v_now
          AND ds.attempt_count < 5
          AND ts.status = 'ACTIVE'
          AND ts.topic = 'catalog.release.published'
          AND we.status = 'ACTIVE'
        ORDER BY ds.next_attempt_at ASC
        LIMIT p_limit
        FOR UPDATE OF ds SKIP LOCKED
    ),
    claimed AS (
        UPDATE integration.delivery_state ds
        SET status        = 'CLAIMED',
            lease_token   = pg_catalog.gen_random_uuid(),
            locked_until  = v_now + INTERVAL '5 minutes',
            attempt_count = ds.attempt_count + 1
        FROM eligible e
        WHERE ds.event_id = e.elig_event_id AND ds.endpoint_id = e.elig_endpoint_id
        RETURNING ds.event_id AS c_event_id, ds.endpoint_id AS c_endpoint_id,
                  ds.lease_token AS c_lease_token, ds.attempt_count AS c_attempt_count,
                  -- P05: Return snapshot fields stored at publication time
                  ds.endpoint_url AS c_endpoint_url,
                  ds.secret AS c_secret,
                  ds.recipient_identity AS c_recipient_identity
    )
    SELECT
        c.c_event_id,
        c.c_endpoint_id,
        c.c_lease_token,
        c.c_endpoint_url,         -- P05: snapshot, not live endpoint
        c.c_secret,               -- P05: snapshot
        c.c_recipient_identity,   -- P05: snapshot
        oe.raw_body,
        c.c_attempt_count
    FROM claimed c
    JOIN integration.outbox_events oe ON oe.id = c.c_event_id;
END;
$$;

REVOKE ALL ON FUNCTION integration.claim_delivery(INT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION integration.claim_delivery(INT) TO gc_dispatcher_worker;

-- ── 12. finalize_delivery RPC ─────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION integration.finalize_delivery(
    p_event_id           UUID,
    p_endpoint_id        UUID,
    p_lease_token        UUID,
    p_outcome            TEXT,
    p_http_status        INT,
    p_response_body      TEXT,
    p_error_message      TEXT,
    p_retry_after_seconds INT,
    p_execution_ms       BIGINT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_state integration.delivery_state;
    v_delay_seconds INT;
BEGIN
    IF p_outcome IS NULL OR p_outcome NOT IN ('SUCCESS', 'DEAD', 'RETRY') THEN
        RAISE EXCEPTION 'finalize_delivery: invalid outcome %', p_outcome;
    END IF;

    SELECT * INTO v_state
    FROM integration.delivery_state
    WHERE event_id = p_event_id AND endpoint_id = p_endpoint_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'finalize_delivery: job not found (event_id=%, endpoint_id=%)', p_event_id, p_endpoint_id;
    END IF;

    IF v_state.status != 'CLAIMED' THEN
        RAISE EXCEPTION 'finalize_delivery: job is not CLAIMED (status=%)', v_state.status;
    END IF;

    IF v_state.lease_token IS DISTINCT FROM p_lease_token THEN
        RAISE EXCEPTION 'finalize_delivery: stale or invalid lease token';
    END IF;

    IF v_state.locked_until < pg_catalog.now() THEN
        RAISE EXCEPTION 'finalize_delivery: lease has expired';
    END IF;

    -- Record attempt history using the reserved attempt_count
    INSERT INTO integration.delivery_attempts
        (event_id, endpoint_id, attempt_number, http_status, response_body, execution_ms)
    VALUES
        (p_event_id, p_endpoint_id, v_state.attempt_count, p_http_status,
         left(COALESCE(p_response_body, p_error_message), 2048), p_execution_ms::INT);

    IF p_outcome = 'SUCCESS' THEN
        UPDATE integration.delivery_state
        SET status = 'SUCCESS', lease_token = NULL, locked_until = NULL
        WHERE event_id = p_event_id AND endpoint_id = p_endpoint_id;

    ELSIF p_outcome = 'DEAD' OR (p_outcome = 'RETRY' AND v_state.attempt_count >= 5) THEN
        UPDATE integration.delivery_state
        SET status = 'DEAD', lease_token = NULL, locked_until = NULL
        WHERE event_id = p_event_id AND endpoint_id = p_endpoint_id;

    ELSIF p_outcome = 'RETRY' THEN
        -- P07e: Bound retry delay (min 1, max 3600 seconds)
        v_delay_seconds := LEAST(GREATEST(COALESCE(p_retry_after_seconds, 60), 1), 3600);
        UPDATE integration.delivery_state
        SET status          = 'PENDING',
            lease_token     = NULL,
            locked_until    = NULL,
            next_attempt_at = pg_catalog.now() + (v_delay_seconds || ' seconds')::INTERVAL
        WHERE event_id = p_event_id AND endpoint_id = p_endpoint_id;
    END IF;

    PERFORM integration.aggregate_outbox_status(p_event_id);
END;
$$;

REVOKE ALL ON FUNCTION integration.finalize_delivery(UUID,UUID,UUID,TEXT,INT,TEXT,TEXT,INT,BIGINT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION integration.finalize_delivery(UUID,UUID,UUID,TEXT,INT,TEXT,TEXT,INT,BIGINT) TO gc_dispatcher_worker;

COMMIT;
