BEGIN;
DROP FUNCTION IF EXISTS public.rpc_get_units;
CREATE OR REPLACE FUNCTION public.rpc_get_units(
    p_country_id uuid,
    p_level_id uuid DEFAULT NULL::uuid,
    p_parent_id uuid DEFAULT NULL::uuid,
    p_status text DEFAULT NULL::text,
    p_search text DEFAULT NULL::text,
    p_limit integer DEFAULT 200,
    p_offset integer DEFAULT 0
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_rows pg_catalog.jsonb;
    v_total INT;
BEGIN
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
          AND (p_level_id IS NULL  OR u.geography_level_id = p_level_id)
          AND (p_parent_id IS NULL OR u.parent_geography_unit_id = p_parent_id)
          AND (p_status IS NULL    OR u.status = p_status)
          AND (p_search IS NULL    OR UPPER(u.display_name) LIKE '%' || UPPER(p_search) || '%'
                                   OR UPPER(u.official_name) LIKE '%' || UPPER(p_search) || '%'
                                   OR u.official_code ILIKE '%' || p_search || '%')
        ORDER BY gl.level_number, u.official_code
        LIMIT p_limit OFFSET p_offset
    ) sub;

    SELECT COUNT(*) INTO v_total
    FROM catalog.geography_units u
    WHERE u.country_id = p_country_id
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
COMMIT;
