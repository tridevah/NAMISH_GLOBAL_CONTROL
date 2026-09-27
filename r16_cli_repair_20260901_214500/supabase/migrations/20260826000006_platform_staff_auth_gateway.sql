-- Migration 000007: Platform Staff Auth Gateway
-- Resolves platform_staff safely without exposing the platform schema

CREATE OR REPLACE FUNCTION public.resolve_platform_staff_authority(
    p_auth_user_id pg_catalog.uuid
) RETURNS pg_catalog.jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog
AS $$
DECLARE
    v_staff_record pg_catalog.record;
BEGIN
    SELECT id, email, role, status
    INTO v_staff_record
    FROM platform.platform_staff
    WHERE id = p_auth_user_id;

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    RETURN pg_catalog.jsonb_build_object(
        'id', v_staff_record.id,
        'email', v_staff_record.email,
        'role', v_staff_record.role,
        'status', v_staff_record.status
    );
END;
$$;

-- Restrict execution exactly to service_role
REVOKE ALL ON FUNCTION public.resolve_platform_staff_authority(pg_catalog.uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.resolve_platform_staff_authority(pg_catalog.uuid) TO service_role;
