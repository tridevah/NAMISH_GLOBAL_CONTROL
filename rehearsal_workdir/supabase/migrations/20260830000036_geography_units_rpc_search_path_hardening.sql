-- Migration: Geography Units RPC Search Path Hardening (Corrected)
-- Hardened search_path = pg_catalog, pg_temp
-- All application objects fully qualified by schema.
-- COALESCE used unqualified (language construct, not a function; resolves correctly regardless of search_path).
-- All catalog.* tables fully qualified. All pg_catalog.* functions explicitly qualified in SQL.

BEGIN;

CREATE OR REPLACE FUNCTION public.rpc_get_units(
    p_country_id       pg_catalog.uuid,
    p_level_id         pg_catalog.uuid DEFAULT NULL,
    p_parent_id        pg_catalog.uuid DEFAULT NULL,
    p_status           pg_catalog.text DEFAULT NULL,
    p_search           pg_catalog.text DEFAULT NULL,
    p_limit            pg_catalog.int4 DEFAULT 200,
    p_offset           pg_catalog.int4 DEFAULT 0
) RETURNS pg_catalog.jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO pg_catalog, pg_temp
AS $$
DECLARE
    v_rows pg_catalog.jsonb;
    v_total pg_catalog.int4;
    v_limit pg_catalog.int4;
    v_offset pg_catalog.int4;
BEGIN
    -- COALESCE is a SQL language construct, not a schema-scoped function; safe without schema prefix
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

    -- All catalog.* objects are fully qualified; pg_catalog.* builtins are schema-qualified in SQL
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
        SELECT u.id, u.country_id, u.geography_level_id,
               gl.level_number, gl.level_key, gl.display_label AS level_label,
               u.parent_geography_unit_id, pu.display_name AS parent_name,
               u.official_code, u.iso_subdivision_code,
               u.official_name, u.display_name, u.status, u.created_at, u.updated_at
        FROM catalog.geography_units u
        JOIN catalog.geography_levels gl ON gl.id = u.geography_level_id
        LEFT JOIN catalog.geography_units pu ON pu.id = u.parent_geography_unit_id
        WHERE u.country_id = p_country_id
          AND gl.level_key = ANY(ARRAY['STATE_UT','DISTRICT','SUB_DISTRICT']::pg_catalog.text[])
          AND (p_level_id IS NULL  OR u.geography_level_id = p_level_id)
          AND (p_parent_id IS NULL OR u.parent_geography_unit_id = p_parent_id)
          AND (p_status IS NULL    OR u.status = p_status)
          AND (p_search IS NULL
               OR pg_catalog.upper(u.display_name)  LIKE '%' || pg_catalog.upper(p_search) || '%'
               OR pg_catalog.upper(u.official_name) LIKE '%' || pg_catalog.upper(p_search) || '%'
               OR u.official_code ILIKE '%' || p_search || '%')
        ORDER BY gl.level_number ASC, u.official_code ASC, u.id ASC
        LIMIT v_limit OFFSET v_offset
    ) sub;

    SELECT COUNT(*)::pg_catalog.int4 INTO v_total
    FROM catalog.geography_units u
    JOIN catalog.geography_levels gl ON gl.id = u.geography_level_id
    WHERE u.country_id = p_country_id
      AND gl.level_key = ANY(ARRAY['STATE_UT','DISTRICT','SUB_DISTRICT']::pg_catalog.text[])
      AND (p_level_id IS NULL  OR u.geography_level_id = p_level_id)
      AND (p_parent_id IS NULL OR u.parent_geography_unit_id = p_parent_id)
      AND (p_status IS NULL    OR u.status = p_status)
      AND (p_search IS NULL
           OR pg_catalog.upper(u.display_name)  LIKE '%' || pg_catalog.upper(p_search) || '%'
           OR pg_catalog.upper(u.official_name) LIKE '%' || pg_catalog.upper(p_search) || '%'
           OR u.official_code ILIKE '%' || p_search || '%');

    RETURN pg_catalog.jsonb_build_object(
        'rows',  COALESCE(v_rows, '[]'::pg_catalog.jsonb),
        'total', v_total
    );
END;
$$;

ALTER FUNCTION public.rpc_get_units(uuid, uuid, uuid, text, text, integer, integer) OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.rpc_get_units(uuid, uuid, uuid, text, text, integer, integer) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.rpc_get_units(uuid, uuid, uuid, text, text, integer, integer) FROM anon;
REVOKE EXECUTE ON FUNCTION public.rpc_get_units(uuid, uuid, uuid, text, text, integer, integer) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_get_units(uuid, uuid, uuid, text, text, integer, integer) TO service_role;

COMMIT;
