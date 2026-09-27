-- =========================================================================================
-- GC MIGRATION: 20260826000007_s2s_rpcs.sql
-- Description: GC S2S provisioning RPCs
-- =========================================================================================

-- 1. reject_if_jwt_replay (Internal)
CREATE OR REPLACE FUNCTION security.reject_if_jwt_replay(
    p_jti TEXT,
    p_issuer TEXT,
    p_audience TEXT,
    p_token_exp TIMESTAMPTZ
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = security, pg_catalog
AS $$
BEGIN
    INSERT INTO security.s2s_jwt_replay_cache (jti, issuer, audience, expires_at)
    VALUES (p_jti, p_issuer, p_audience, p_token_exp);
END;
$$;

REVOKE ALL ON FUNCTION security.reject_if_jwt_replay FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION security.reject_if_jwt_replay TO service_role;

-- 2. s2s_reject_if_jwt_replay (Public Wrapper)
CREATE OR REPLACE FUNCTION public.s2s_reject_if_jwt_replay(
    p_jti TEXT,
    p_issuer TEXT,
    p_audience TEXT,
    p_token_exp TIMESTAMPTZ
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
    PERFORM security.reject_if_jwt_replay(p_jti, p_issuer, p_audience, p_token_exp);
END;
$$;

REVOKE ALL ON FUNCTION public.s2s_reject_if_jwt_replay FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.s2s_reject_if_jwt_replay TO service_role;


-- 3. s2s_provision_enterprise_atomic
CREATE OR REPLACE FUNCTION public.s2s_provision_enterprise_atomic(
    p_email TEXT,
    p_full_name TEXT,
    p_idempotency_key TEXT,
    p_erp_app_user_id UUID
)
RETURNS TABLE (platform_account_id UUID)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, platform, integration, pg_catalog
AS $$
DECLARE
    v_platform_account_id UUID;
    v_binding RECORD;
BEGIN
    SET LOCAL lock_timeout = '5s';
    
    -- Serialize concurrent provisions for the same ERP user
    PERFORM pg_advisory_xact_lock(hashtext('erp_acct:' || p_erp_app_user_id::text));

    SELECT * INTO v_binding FROM platform.erp_account_bindings WHERE erp_app_user_id = p_erp_app_user_id;

    IF FOUND THEN
        IF v_binding.provisioned_email != p_email OR v_binding.provisioned_name != p_full_name THEN
            RAISE EXCEPTION 'Immutable field conflict' USING ERRCODE = '23514';
        END IF;
        RETURN QUERY SELECT v_binding.platform_account_id;
        RETURN;
    END IF;

    INSERT INTO platform.platform_accounts (name) VALUES (p_full_name) RETURNING id INTO v_platform_account_id;

    INSERT INTO platform.erp_account_bindings (platform_account_id, erp_app_user_id, provisioned_email, provisioned_name, idempotency_key)
    VALUES (v_platform_account_id, p_erp_app_user_id, p_email, p_full_name, p_idempotency_key);

    INSERT INTO integration.idempotency_records (key) VALUES (p_idempotency_key) ON CONFLICT DO NOTHING;

    RETURN QUERY SELECT v_platform_account_id;
END;
$$;

REVOKE ALL ON FUNCTION public.s2s_provision_enterprise_atomic FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.s2s_provision_enterprise_atomic TO service_role;
