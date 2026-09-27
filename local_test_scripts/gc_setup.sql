-- GC Mock Setup for fn_publish_release

CREATE SCHEMA IF NOT EXISTS catalog;

CREATE TABLE catalog.catalog_release_items (
    item_id UUID PRIMARY KEY,
    release_id UUID,
    item_type TEXT,
    payload JSONB
);

CREATE TABLE integration.topic_subscriptions (
    id UUID PRIMARY KEY,
    topic TEXT,
    endpoint_id UUID,
    status TEXT
);

CREATE TABLE integration.webhook_endpoints (
    id UUID PRIMARY KEY,
    url TEXT,
    secret TEXT,
    description TEXT,
    status TEXT
);

CREATE TABLE integration.outbox_events (
    id UUID PRIMARY KEY,
    event_type TEXT,
    idempotency_key TEXT,
    payload JSONB,
    raw_body TEXT,
    created_at TIMESTAMPTZ
);

CREATE TABLE integration.delivery_state (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID,
    endpoint_id UUID,
    endpoint_url TEXT,
    secret TEXT,
    recipient_identity TEXT,
    status TEXT,
    next_attempt_at TIMESTAMPTZ
);

CREATE SEQUENCE catalog.release_seq;

-- Insert subscription
INSERT INTO integration.webhook_endpoints (id, url, secret, description, status) 
VALUES ('11111111-1111-1111-1111-111111111111', 'https://erp.test/api/webhook', 'whsec_testsecret', 'ERP Test', 'ACTIVE');

INSERT INTO integration.topic_subscriptions (id, topic, endpoint_id, status)
VALUES ('22222222-2222-2222-2222-222222222222', 'catalog.release.published', '11111111-1111-1111-1111-111111111111', 'ACTIVE');

CREATE TABLE catalog.catalog_releases (
    id UUID PRIMARY KEY,
    version TEXT,
    status TEXT,
    published_at TIMESTAMPTZ,
    release_sequence BIGINT,
    hsn_sac_intentionally_empty BOOLEAN DEFAULT FALSE,
    tax_profiles_intentionally_empty BOOLEAN DEFAULT FALSE,
    units_intentionally_empty BOOLEAN DEFAULT FALSE
);
