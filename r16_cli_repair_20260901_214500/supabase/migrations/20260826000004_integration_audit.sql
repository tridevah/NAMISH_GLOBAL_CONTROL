
CREATE TABLE integration.webhook_endpoints (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    url TEXT NOT NULL,
    secret TEXT NOT NULL,
    description TEXT,
    status TEXT DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE integration.webhook_endpoints ENABLE ROW LEVEL SECURITY;
ALTER TABLE integration.webhook_endpoints FORCE ROW LEVEL SECURITY;

CREATE TABLE integration.outbox_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type TEXT NOT NULL,
    payload JSONB NOT NULL,
    idempotency_key TEXT UNIQUE NOT NULL,
    status TEXT NOT NULL DEFAULT 'PENDING',
    created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE integration.outbox_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE integration.outbox_events FORCE ROW LEVEL SECURITY;

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

CREATE TABLE integration.idempotency_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key TEXT UNIQUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE integration.idempotency_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE integration.idempotency_records FORCE ROW LEVEL SECURITY;

CREATE TABLE audit.staff_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    staff_id UUID NOT NULL REFERENCES platform.platform_staff(id),
    action TEXT NOT NULL,
    resource TEXT NOT NULL,
    resource_id UUID,
    payload JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE audit.staff_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit.staff_events FORCE ROW LEVEL SECURITY;

CREATE TABLE audit.publication_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    release_id UUID NOT NULL REFERENCES catalog.catalog_releases(id),
    staff_id UUID NOT NULL REFERENCES platform.platform_staff(id),
    published_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE audit.publication_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit.publication_history FORCE ROW LEVEL SECURITY;
