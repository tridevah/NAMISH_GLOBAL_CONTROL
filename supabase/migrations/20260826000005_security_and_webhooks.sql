
-- Direct mutation denied unless explicitly required.
-- No anonymous writes.
-- We will only grant SELECT, INSERT, UPDATE, DELETE to service_role, and maybe SELECT to authenticated if strictly required, but requirements say "No tenant or ERP user access. No anonymous writes."
-- And "Direct mutation denied unless explicitly required."
-- So we just grant ALL to service_role and nothing to authenticated/anon.

GRANT USAGE ON SCHEMA platform TO service_role;
GRANT USAGE ON SCHEMA billing TO service_role;
GRANT USAGE ON SCHEMA catalog TO service_role;
GRANT USAGE ON SCHEMA integration TO service_role;
GRANT USAGE ON SCHEMA audit TO service_role;

GRANT ALL ON ALL TABLES IN SCHEMA platform TO service_role;
GRANT ALL ON ALL TABLES IN SCHEMA billing TO service_role;
GRANT ALL ON ALL TABLES IN SCHEMA catalog TO service_role;
GRANT ALL ON ALL TABLES IN SCHEMA integration TO service_role;
GRANT ALL ON ALL TABLES IN SCHEMA audit TO service_role;

-- Revoke from public, anon, authenticated (just in case)
REVOKE ALL ON ALL TABLES IN SCHEMA platform FROM public, anon, authenticated;
REVOKE ALL ON ALL TABLES IN SCHEMA billing FROM public, anon, authenticated;
REVOKE ALL ON ALL TABLES IN SCHEMA catalog FROM public, anon, authenticated;
REVOKE ALL ON ALL TABLES IN SCHEMA integration FROM public, anon, authenticated;
REVOKE ALL ON ALL TABLES IN SCHEMA audit FROM public, anon, authenticated;

-- Function to safely enqueue a webhook
CREATE OR REPLACE FUNCTION integration.enqueue_webhook(
    p_event_type pg_catalog.text,
    p_payload pg_catalog.jsonb,
    p_idempotency_key pg_catalog.text
) RETURNS pg_catalog.uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog
AS $$
DECLARE
    v_id pg_catalog.uuid;
BEGIN
    INSERT INTO integration.outbox_events (event_type, payload, idempotency_key, status, created_at)
    VALUES (p_event_type, p_payload, p_idempotency_key, 'PENDING', pg_catalog.now())
    RETURNING id INTO v_id;
    RETURN v_id;
END;
$$;
GRANT EXECUTE ON FUNCTION integration.enqueue_webhook(pg_catalog.text, pg_catalog.jsonb, pg_catalog.text) TO service_role;
REVOKE ALL ON FUNCTION integration.enqueue_webhook(pg_catalog.text, pg_catalog.jsonb, pg_catalog.text) FROM PUBLIC, anon, authenticated;

-- HMAC-SHA256 signature logic for webhooks (just an example of how it's structurally planned, actual signing happens in Edge Function or Node.js backend).
-- Requirement: "HMAC-SHA256 contract using timestamp + event ID + raw body"
-- We don't necessarily need to implement the signing in pgsql, we can do it in the Next.js API route that acts as the webhook dispatcher.
