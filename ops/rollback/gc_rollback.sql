-- GC V2R2 Bootstrap Rollback
BEGIN;

-- Safety guard: Do not rollback if traffic has already been served
DO $$
DECLARE
    v_events BIGINT;
    v_seq    BIGINT;
BEGIN
    SELECT count(*) INTO v_events FROM integration.outbox_events WHERE event_type = 'catalog.release.published';
    IF v_events > 0 THEN
        RAISE EXCEPTION 'Rollback blocked: % published events exist in outbox', v_events;
    END IF;
    
    SELECT last_value INTO v_seq FROM catalog.release_seq;
    IF v_seq > 1 THEN
        RAISE EXCEPTION 'Rollback blocked: release sequence has advanced past seed';
    END IF;
END;
$$;

-- Drop Triggers
DROP TRIGGER IF EXISTS trg_protect_published_items ON catalog.catalog_release_items;
DROP TRIGGER IF EXISTS trg_block_published_insert ON catalog.catalog_releases;
DROP TRIGGER IF EXISTS trg_publish_release ON catalog.catalog_releases;
DROP TRIGGER IF EXISTS trg_outbox_raw_body_immutable ON integration.outbox_events;
DROP TRIGGER IF EXISTS trg_outbox_immutable ON integration.outbox_events;
DROP TRIGGER IF EXISTS trg_outbox_no_truncate ON integration.outbox_events;
DROP TRIGGER IF EXISTS trg_sync_control_immutable ON catalog.catalog_sync_control;
DROP TRIGGER IF EXISTS trg_sync_control_no_truncate ON catalog.catalog_sync_control;
DROP TRIGGER IF EXISTS trg_delivery_attempts_immutable ON integration.delivery_attempts;

-- Drop Functions
DROP FUNCTION IF EXISTS integration.finalize_delivery(UUID,UUID,UUID,TEXT,INT,TEXT,TEXT,INT,BIGINT);
DROP FUNCTION IF EXISTS integration.claim_delivery(INT);
DROP FUNCTION IF EXISTS integration.aggregate_outbox_status(UUID);
DROP FUNCTION IF EXISTS catalog.fn_protect_published_items();
DROP FUNCTION IF EXISTS catalog.fn_block_direct_published_insert();
DROP FUNCTION IF EXISTS catalog.fn_publish_release();
DROP FUNCTION IF EXISTS catalog.fn_validate_release_items(UUID);
DROP FUNCTION IF EXISTS integration.fn_prevent_attempts_mutation();
DROP FUNCTION IF EXISTS integration.fn_prevent_outbox_mutation();
DROP FUNCTION IF EXISTS integration.fn_prevent_raw_body_mutation();
DROP FUNCTION IF EXISTS integration.fn_prevent_outbox_truncate();
DROP FUNCTION IF EXISTS catalog.fn_prevent_sync_control_mutation();
DROP FUNCTION IF EXISTS catalog.fn_prevent_mutation();

-- Drop Tables
DROP TABLE IF EXISTS integration.delivery_state CASCADE;
DROP TABLE IF EXISTS integration.topic_subscriptions CASCADE;
DROP TABLE IF EXISTS catalog.catalog_sync_control CASCADE;

-- Revert Columns
ALTER TABLE catalog.catalog_releases
    DROP COLUMN IF EXISTS release_sequence,
    DROP COLUMN IF EXISTS hsn_sac_intentionally_empty,
    DROP COLUMN IF EXISTS tax_profiles_intentionally_empty,
    DROP COLUMN IF EXISTS units_intentionally_empty;

ALTER TABLE integration.outbox_events DROP COLUMN IF EXISTS raw_body;

-- Recreate legacy delivery_attempts
DROP TABLE IF EXISTS integration.delivery_attempts CASCADE;
CREATE TABLE integration.delivery_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES integration.outbox_events(id),
    endpoint_id UUID NOT NULL REFERENCES integration.webhook_endpoints(id),
    status TEXT NOT NULL,
    response_code INT,
    response_body TEXT,
    attempted_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE integration.delivery_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE integration.delivery_attempts FORCE ROW LEVEL SECURITY;
GRANT ALL ON integration.delivery_attempts TO service_role;

-- Drop Sequences
DROP SEQUENCE IF EXISTS catalog.release_seq CASCADE;

-- Revert Roles
REVOKE ALL ON SCHEMA integration FROM gc_dispatcher_worker;
DROP ROLE IF EXISTS gc_dispatcher_worker;

COMMIT;
