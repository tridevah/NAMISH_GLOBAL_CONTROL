-- Migration: Geography Units Pagination, Security & Filtering Correction
-- Requirement: Ensure correct pagination, strict authorization, and exclusion of LOCALITY rows.

BEGIN;

-- Ensure the function is dropped before recreating it to reset any lingering ACLs/defaults
DROP FUNCTION IF EXISTS public.rpc_get_units(uuid, uuid, uuid, text, text, integer, integer);

CREATE OR REPLACE FUNCTION public.rpc_get_units(
    p_country_id       pg_catalog.uuid,
    p_level_id         pg_catalog.uuid DEFAULT NULL,
    p_parent_id        pg_catalog.uuid DEFAULT NULL,
    p_status           TEXT            DEFAULT NULL,
    p_search           TEXT            DEFAULT NULL,
    p_limit            INT             DEFAULT 200,
    p_offset           INT             DEFAULT 0
) RETURNS pg_catalog.jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO catalog, public, pg_catalog
AS $$
DECLARE
    v_rows pg_catalog.jsonb;
    v_total INT;
    v_limit INT;
    v_offset INT;
BEGIN
    -- Clamp and validate inputs
    v_limit := COALESCE(p_limit, 200);
    IF v_limit > 500 THEN
        v_limit := 500;
    ELSIF v_limit < 1 THEN
        v_limit := 1;
    END IF;

    v_offset := COALESCE(p_offset, 0);
    IF v_offset < 0 THEN
        v_offset := 0;
    END IF;

    -- Aggregate paginated rows
    SELECT pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
            'id',                      sub.id,
            'country_id',              sub.country_id,
            'geography_level_id',      sub.geography_level_id,
            'level_number',            sub.level_number,
            'level_key',               sub.level_key,
            'level_label',             sub.level_label,
            'parent_geography_unit_id', sub.parent_geography_unit_id,
            'parent_name',             sub.parent_name,
            'official_code',           sub.official_code,
            'iso_subdivision_code',    sub.iso_subdivision_code,
            'official_name',           sub.official_name,
            'display_name',            sub.display_name,
            'status',                  sub.status,
            'created_at',              sub.created_at,
            'updated_at',              sub.updated_at
        )
    ) INTO v_rows
    FROM (
        SELECT u.id, u.country_id, u.geography_level_id, gl.level_number, gl.level_key, gl.display_label as level_label,
               u.parent_geography_unit_id, pu.display_name as parent_name, u.official_code, u.iso_subdivision_code,
               u.official_name, u.display_name, u.status, u.created_at, u.updated_at
        FROM catalog.geography_units u
        JOIN catalog.geography_levels gl ON gl.id = u.geography_level_id
        LEFT JOIN catalog.geography_units pu ON pu.id = u.parent_geography_unit_id
        WHERE u.country_id = p_country_id
          AND gl.level_key IN ('STATE_UT', 'DISTRICT', 'SUB_DISTRICT')
          AND (p_level_id IS NULL  OR u.geography_level_id = p_level_id)
          AND (p_parent_id IS NULL OR u.parent_geography_unit_id = p_parent_id)
          AND (p_status IS NULL    OR u.status = p_status)
          AND (p_search IS NULL    OR UPPER(u.display_name) LIKE '%' || UPPER(p_search) || '%'
                                   OR UPPER(u.official_name) LIKE '%' || UPPER(p_search) || '%'
                                   OR u.official_code ILIKE '%' || p_search || '%')
        ORDER BY gl.level_number ASC, u.official_code ASC, u.id ASC
        LIMIT v_limit OFFSET v_offset
    ) sub;

    -- Total count with exact identical predicates
    SELECT COUNT(*) INTO v_total
    FROM catalog.geography_units u
    JOIN catalog.geography_levels gl ON gl.id = u.geography_level_id
    WHERE u.country_id = p_country_id
      AND gl.level_key IN ('STATE_UT', 'DISTRICT', 'SUB_DISTRICT')
      AND (p_level_id IS NULL  OR u.geography_level_id = p_level_id)
      AND (p_parent_id IS NULL OR u.parent_geography_unit_id = p_parent_id)
      AND (p_status IS NULL    OR u.status = p_status)
      AND (p_search IS NULL    OR UPPER(u.display_name) LIKE '%' || UPPER(p_search) || '%'
                               OR UPPER(u.official_name) LIKE '%' || UPPER(p_search) || '%'
                               OR u.official_code ILIKE '%' || p_search || '%');

    RETURN pg_catalog.jsonb_build_object(
        'rows',  COALESCE(v_rows, '[]'::pg_catalog.jsonb),
        'total', v_total
    );
END;
$$;

-- Secure the newly created function
ALTER FUNCTION public.rpc_get_units(uuid, uuid, uuid, text, text, integer, integer) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.rpc_get_units(uuid, uuid, uuid, text, text, integer, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.rpc_get_units(uuid, uuid, uuid, text, text, integer, integer) FROM anon;
REVOKE ALL ON FUNCTION public.rpc_get_units(uuid, uuid, uuid, text, text, integer, integer) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_get_units(uuid, uuid, uuid, text, text, integer, integer) TO service_role;

COMMIT;
