-- =========================================================================================
-- GC MIGRATION: 20260826000006_s2s_provisioning.sql
-- Description: GC S2S provisioning schema and replay cache
-- =========================================================================================

-- 1. security schema
CREATE SCHEMA IF NOT EXISTS security;

-- 2. security.s2s_jwt_replay_cache
CREATE TABLE security.s2s_jwt_replay_cache (
    jti TEXT NOT NULL,
    issuer TEXT NOT NULL,
    audience TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (jti, issuer, audience)
);

ALTER TABLE security.s2s_jwt_replay_cache ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON security.s2s_jwt_replay_cache FROM PUBLIC, anon, authenticated;
GRANT ALL ON security.s2s_jwt_replay_cache TO service_role;

-- 3. platform.erp_account_bindings
CREATE TABLE platform.erp_account_bindings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    platform_account_id UUID NOT NULL REFERENCES platform.platform_accounts(id) ON DELETE RESTRICT,
    erp_app_user_id UUID NOT NULL UNIQUE,
    provisioned_email TEXT NOT NULL,
    provisioned_name TEXT NOT NULL,
    idempotency_key TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE platform.erp_account_bindings ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON platform.erp_account_bindings FROM PUBLIC, anon, authenticated;
GRANT ALL ON platform.erp_account_bindings TO service_role;

