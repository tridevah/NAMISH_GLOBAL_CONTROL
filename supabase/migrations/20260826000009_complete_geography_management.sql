-- Migration 000009: Complete Geography Management RPCs
-- Adds full CRUD gateway for levels, units, postal codes and mappings.
-- All functions: SECURITY DEFINER, search_path = pg_catalog,
--   REVOKE from PUBLIC/anon/authenticated, GRANT to service_role only.

-- ============================================================
-- HELPER: audit log writer
-- ============================================================
CREATE OR REPLACE FUNCTION public.rpc_write_audit(
    p_staff_id    pg_catalog.uuid,
    p_action      TEXT,
    p_resource    TEXT,
    p_resource_id pg_catalog.uuid,
    p_payload     pg_catalog.jsonb
) RETURNS void
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO pg_catalog
AS $$
BEGIN
    INSERT INTO audit.staff_events(staff_id, action, resource, resource_id, payload)
    VALUES (p_staff_id, p_action, p_resource, p_resource_id, p_payload);
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_write_audit(pg_catalog.uuid, TEXT, TEXT, pg_catalog.uuid, pg_catalog.jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.rpc_write_audit(pg_catalog.uuid, TEXT, TEXT, pg_catalog.uuid, pg_catalog.jsonb) FROM anon;
REVOKE ALL ON FUNCTION public.rpc_write_audit(pg_catalog.uuid, TEXT, TEXT, pg_catalog.uuid, pg_catalog.jsonb) FROM authenticated;
GRANT  ALL ON FUNCTION public.rpc_write_audit(pg_catalog.uuid, TEXT, TEXT, pg_catalog.uuid, pg_catalog.jsonb) TO service_role;

-- ============================================================
-- GEOGRAPHY LEVELS
-- ============================================================

CREATE OR REPLACE FUNCTION public.rpc_create_level(
    p_country_id   pg_catalog.uuid,
    p_level_number INT,
    p_level_key    TEXT,
    p_display_label TEXT,
    p_staff_id     pg_catalog.uuid
) RETURNS pg_catalog.jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO pg_catalog
AS $$
DECLARE
    v_record catalog.geography_levels;
    v_max    INT;
BEGIN
    -- Prevent ordering gaps: new level must equal max+1 or 1
    SELECT COALESCE(MAX(level_number), 0) INTO v_max
    FROM catalog.geography_levels
    WHERE country_id = p_country_id;

    IF p_level_number != v_max + 1 THEN
        RAISE EXCEPTION 'Level number must be sequential. Expected %, got %', v_max + 1, p_level_number;
    END IF;

    INSERT INTO catalog.geography_levels(
        country_id, level_number, level_key, display_label,
        status, created_by, updated_by
    ) VALUES (
        p_country_id, p_level_number, p_level_key, p_display_label,
        'ACTIVE', p_staff_id, p_staff_id
    ) RETURNING * INTO v_record;

    PERFORM public.rpc_write_audit(
        p_staff_id, 'CREATE', 'catalog.geography_levels', v_record.id,
        pg_catalog.jsonb_build_object(
            'country_id', p_country_id,
            'level_number', p_level_number,
            'level_key', p_level_key,
            'display_label', p_display_label
        )
    );

    RETURN pg_catalog.to_jsonb(v_record);
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_create_level(pg_catalog.uuid, INT, TEXT, TEXT, pg_catalog.uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.rpc_create_level(pg_catalog.uuid, INT, TEXT, TEXT, pg_catalog.uuid) FROM anon;
REVOKE ALL ON FUNCTION public.rpc_create_level(pg_catalog.uuid, INT, TEXT, TEXT, pg_catalog.uuid) FROM authenticated;
GRANT  ALL ON FUNCTION public.rpc_create_level(pg_catalog.uuid, INT, TEXT, TEXT, pg_catalog.uuid) TO service_role;

-- ----------

CREATE OR REPLACE FUNCTION public.rpc_update_level(
    p_id            pg_catalog.uuid,
    p_display_label TEXT,
    p_status        TEXT,
    p_staff_id      pg_catalog.uuid
) RETURNS pg_catalog.jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO pg_catalog
AS $$
DECLARE
    v_record catalog.geography_levels;
BEGIN
    IF p_status NOT IN ('ACTIVE', 'INACTIVE') THEN
        RAISE EXCEPTION 'Invalid status: %', p_status;
    END IF;

    UPDATE catalog.geography_levels
    SET display_label = p_display_label,
        status        = p_status,
        updated_at    = NOW(),
        updated_by    = p_staff_id
    WHERE id = p_id
    RETURNING * INTO v_record;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Geography level % not found', p_id;
    END IF;

    PERFORM public.rpc_write_audit(
        p_staff_id, 'UPDATE', 'catalog.geography_levels', p_id,
        pg_catalog.jsonb_build_object('display_label', p_display_label, 'status', p_status)
    );

    RETURN pg_catalog.to_jsonb(v_record);
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_update_level(pg_catalog.uuid, TEXT, TEXT, pg_catalog.uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.rpc_update_level(pg_catalog.uuid, TEXT, TEXT, pg_catalog.uuid) FROM anon;
REVOKE ALL ON FUNCTION public.rpc_update_level(pg_catalog.uuid, TEXT, TEXT, pg_catalog.uuid) FROM authenticated;
GRANT  ALL ON FUNCTION public.rpc_update_level(pg_catalog.uuid, TEXT, TEXT, pg_catalog.uuid) TO service_role;

-- ============================================================
-- GEOGRAPHY UNITS
-- ============================================================

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
    SET search_path TO pg_catalog
AS $$
DECLARE
    v_rows pg_catalog.jsonb;
    v_total INT;
BEGIN
    SELECT pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
            'id',                      u.id,
            'country_id',              u.country_id,
            'geography_level_id',      u.geography_level_id,
            'level_number',            gl.level_number,
            'level_key',               gl.level_key,
            'level_label',             gl.display_label,
            'parent_geography_unit_id', u.parent_geography_unit_id,
            'parent_name',             pu.display_name,
            'official_code',           u.official_code,
            'iso_subdivision_code',    u.iso_subdivision_code,
            'official_name',           u.official_name,
            'display_name',            u.display_name,
            'status',                  u.status,
            'created_at',              u.created_at,
            'updated_at',              u.updated_at
        ) ORDER BY gl.level_number, u.official_code
    ) INTO v_rows
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
    LIMIT p_limit OFFSET p_offset;

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

REVOKE ALL ON FUNCTION public.rpc_get_units(pg_catalog.uuid, pg_catalog.uuid, pg_catalog.uuid, TEXT, TEXT, INT, INT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.rpc_get_units(pg_catalog.uuid, pg_catalog.uuid, pg_catalog.uuid, TEXT, TEXT, INT, INT) FROM anon;
REVOKE ALL ON FUNCTION public.rpc_get_units(pg_catalog.uuid, pg_catalog.uuid, pg_catalog.uuid, TEXT, TEXT, INT, INT) FROM authenticated;
GRANT  ALL ON FUNCTION public.rpc_get_units(pg_catalog.uuid, pg_catalog.uuid, pg_catalog.uuid, TEXT, TEXT, INT, INT) TO service_role;

-- ----------

CREATE OR REPLACE FUNCTION public.rpc_create_unit(
    p_country_id              pg_catalog.uuid,
    p_geography_level_id      pg_catalog.uuid,
    p_parent_geography_unit_id pg_catalog.uuid,
    p_official_code           TEXT,
    p_iso_subdivision_code    TEXT,
    p_official_name           TEXT,
    p_display_name            TEXT,
    p_staff_id                pg_catalog.uuid
) RETURNS pg_catalog.jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO pg_catalog
AS $$
DECLARE
    v_record catalog.geography_units;
BEGIN
    INSERT INTO catalog.geography_units(
        country_id, geography_level_id, parent_geography_unit_id,
        official_code, iso_subdivision_code, official_name, display_name,
        status, created_by, updated_by
    ) VALUES (
        p_country_id, p_geography_level_id, p_parent_geography_unit_id,
        p_official_code, NULLIF(p_iso_subdivision_code, ''), p_official_name, p_display_name,
        'ACTIVE', p_staff_id, p_staff_id
    ) RETURNING * INTO v_record;

    PERFORM public.rpc_write_audit(
        p_staff_id, 'CREATE', 'catalog.geography_units', v_record.id,
        pg_catalog.jsonb_build_object(
            'country_id', p_country_id,
            'geography_level_id', p_geography_level_id,
            'parent_geography_unit_id', p_parent_geography_unit_id,
            'official_code', p_official_code,
            'official_name', p_official_name,
            'display_name', p_display_name
        )
    );

    RETURN pg_catalog.to_jsonb(v_record);
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_create_unit(pg_catalog.uuid, pg_catalog.uuid, pg_catalog.uuid, TEXT, TEXT, TEXT, TEXT, pg_catalog.uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.rpc_create_unit(pg_catalog.uuid, pg_catalog.uuid, pg_catalog.uuid, TEXT, TEXT, TEXT, TEXT, pg_catalog.uuid) FROM anon;
REVOKE ALL ON FUNCTION public.rpc_create_unit(pg_catalog.uuid, pg_catalog.uuid, pg_catalog.uuid, TEXT, TEXT, TEXT, TEXT, pg_catalog.uuid) FROM authenticated;
GRANT  ALL ON FUNCTION public.rpc_create_unit(pg_catalog.uuid, pg_catalog.uuid, pg_catalog.uuid, TEXT, TEXT, TEXT, TEXT, pg_catalog.uuid) TO service_role;

-- ----------

CREATE OR REPLACE FUNCTION public.rpc_update_unit(
    p_id                 pg_catalog.uuid,
    p_official_name      TEXT,
    p_display_name       TEXT,
    p_iso_subdivision_code TEXT,
    p_status             TEXT,
    p_staff_id           pg_catalog.uuid
) RETURNS pg_catalog.jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO pg_catalog
AS $$
DECLARE
    v_record catalog.geography_units;
BEGIN
    IF p_status NOT IN ('ACTIVE', 'INACTIVE') THEN
        RAISE EXCEPTION 'Invalid status: %', p_status;
    END IF;

    UPDATE catalog.geography_units
    SET official_name       = p_official_name,
        display_name        = p_display_name,
        iso_subdivision_code = NULLIF(p_iso_subdivision_code, ''),
        status              = p_status,
        updated_at          = NOW(),
        updated_by          = p_staff_id
    WHERE id = p_id
    RETURNING * INTO v_record;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Geography unit % not found', p_id;
    END IF;

    PERFORM public.rpc_write_audit(
        p_staff_id, 'UPDATE', 'catalog.geography_units', p_id,
        pg_catalog.jsonb_build_object(
            'official_name', p_official_name,
            'display_name', p_display_name,
            'status', p_status
        )
    );

    RETURN pg_catalog.to_jsonb(v_record);
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_update_unit(pg_catalog.uuid, TEXT, TEXT, TEXT, TEXT, pg_catalog.uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.rpc_update_unit(pg_catalog.uuid, TEXT, TEXT, TEXT, TEXT, pg_catalog.uuid) FROM anon;
REVOKE ALL ON FUNCTION public.rpc_update_unit(pg_catalog.uuid, TEXT, TEXT, TEXT, TEXT, pg_catalog.uuid) FROM authenticated;
GRANT  ALL ON FUNCTION public.rpc_update_unit(pg_catalog.uuid, TEXT, TEXT, TEXT, TEXT, pg_catalog.uuid) TO service_role;

-- ============================================================
-- POSTAL CODES
-- ============================================================

CREATE OR REPLACE FUNCTION public.rpc_get_postal_codes(
    p_country_id pg_catalog.uuid,
    p_status     TEXT DEFAULT NULL,
    p_search     TEXT DEFAULT NULL,
    p_limit      INT  DEFAULT 100,
    p_offset     INT  DEFAULT 0
) RETURNS pg_catalog.jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO pg_catalog
AS $$
DECLARE
    v_rows  pg_catalog.jsonb;
    v_total INT;
BEGIN
    SELECT pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
            'id',          pc.id,
            'country_id',  pc.country_id,
            'postal_code', pc.postal_code,
            'status',      pc.status,
            'created_at',  pc.created_at,
            'updated_at',  pc.updated_at,
            'mappings',    COALESCE((
                SELECT pg_catalog.jsonb_agg(
                    pg_catalog.jsonb_build_object(
                        'geography_unit_id', pcg.geography_unit_id,
                        'unit_name', gu.display_name,
                        'level_label', gl.display_label
                    )
                )
                FROM catalog.postal_code_geographies pcg
                JOIN catalog.geography_units gu ON gu.id = pcg.geography_unit_id
                JOIN catalog.geography_levels gl ON gl.id = gu.geography_level_id
                WHERE pcg.postal_code_id = pc.id
            ), '[]'::pg_catalog.jsonb)
        ) ORDER BY pc.postal_code
    ) INTO v_rows
    FROM catalog.postal_codes pc
    WHERE pc.country_id = p_country_id
      AND (p_status IS NULL OR pc.status = p_status)
      AND (p_search IS NULL OR pc.postal_code ILIKE '%' || p_search || '%')
    LIMIT p_limit OFFSET p_offset;

    SELECT COUNT(*) INTO v_total
    FROM catalog.postal_codes pc
    WHERE pc.country_id = p_country_id
      AND (p_status IS NULL OR pc.status = p_status)
      AND (p_search IS NULL OR pc.postal_code ILIKE '%' || p_search || '%');

    RETURN pg_catalog.jsonb_build_object(
        'rows',  COALESCE(v_rows, '[]'::pg_catalog.jsonb),
        'total', v_total
    );
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_get_postal_codes(pg_catalog.uuid, TEXT, TEXT, INT, INT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.rpc_get_postal_codes(pg_catalog.uuid, TEXT, TEXT, INT, INT) FROM anon;
REVOKE ALL ON FUNCTION public.rpc_get_postal_codes(pg_catalog.uuid, TEXT, TEXT, INT, INT) FROM authenticated;
GRANT  ALL ON FUNCTION public.rpc_get_postal_codes(pg_catalog.uuid, TEXT, TEXT, INT, INT) TO service_role;

-- ----------

CREATE OR REPLACE FUNCTION public.rpc_create_postal_code(
    p_country_id  pg_catalog.uuid,
    p_postal_code TEXT,
    p_staff_id    pg_catalog.uuid
) RETURNS pg_catalog.jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO pg_catalog
AS $$
DECLARE
    v_record catalog.postal_codes;
BEGIN
    INSERT INTO catalog.postal_codes(country_id, postal_code, status, created_by, updated_by)
    VALUES (p_country_id, p_postal_code, 'ACTIVE', p_staff_id, p_staff_id)
    RETURNING * INTO v_record;

    PERFORM public.rpc_write_audit(
        p_staff_id, 'CREATE', 'catalog.postal_codes', v_record.id,
        pg_catalog.jsonb_build_object('country_id', p_country_id, 'postal_code', p_postal_code)
    );

    RETURN pg_catalog.to_jsonb(v_record);
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_create_postal_code(pg_catalog.uuid, TEXT, pg_catalog.uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.rpc_create_postal_code(pg_catalog.uuid, TEXT, pg_catalog.uuid) FROM anon;
REVOKE ALL ON FUNCTION public.rpc_create_postal_code(pg_catalog.uuid, TEXT, pg_catalog.uuid) FROM authenticated;
GRANT  ALL ON FUNCTION public.rpc_create_postal_code(pg_catalog.uuid, TEXT, pg_catalog.uuid) TO service_role;

-- ----------

CREATE OR REPLACE FUNCTION public.rpc_update_postal_code(
    p_id          pg_catalog.uuid,
    p_postal_code TEXT,
    p_status      TEXT,
    p_staff_id    pg_catalog.uuid
) RETURNS pg_catalog.jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO pg_catalog
AS $$
DECLARE
    v_record catalog.postal_codes;
BEGIN
    IF p_status NOT IN ('ACTIVE', 'INACTIVE') THEN
        RAISE EXCEPTION 'Invalid status: %', p_status;
    END IF;

    UPDATE catalog.postal_codes
    SET postal_code = p_postal_code,
        status      = p_status,
        updated_at  = NOW(),
        updated_by  = p_staff_id
    WHERE id = p_id
    RETURNING * INTO v_record;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Postal code % not found', p_id;
    END IF;

    PERFORM public.rpc_write_audit(
        p_staff_id, 'UPDATE', 'catalog.postal_codes', p_id,
        pg_catalog.jsonb_build_object('postal_code', p_postal_code, 'status', p_status)
    );

    RETURN pg_catalog.to_jsonb(v_record);
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_update_postal_code(pg_catalog.uuid, TEXT, TEXT, pg_catalog.uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.rpc_update_postal_code(pg_catalog.uuid, TEXT, TEXT, pg_catalog.uuid) FROM anon;
REVOKE ALL ON FUNCTION public.rpc_update_postal_code(pg_catalog.uuid, TEXT, TEXT, pg_catalog.uuid) FROM authenticated;
GRANT  ALL ON FUNCTION public.rpc_update_postal_code(pg_catalog.uuid, TEXT, TEXT, pg_catalog.uuid) TO service_role;

-- ----------

CREATE OR REPLACE FUNCTION public.rpc_set_postal_mappings(
    p_postal_code_id    pg_catalog.uuid,
    p_geography_unit_ids pg_catalog.uuid[],
    p_staff_id          pg_catalog.uuid
) RETURNS void
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO pg_catalog
AS $$
DECLARE
    v_country_id pg_catalog.uuid;
    v_uid        pg_catalog.uuid;
BEGIN
    SELECT country_id INTO v_country_id
    FROM catalog.postal_codes WHERE id = p_postal_code_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Postal code % not found', p_postal_code_id;
    END IF;

    -- Validate each unit belongs to same country
    FOREACH v_uid IN ARRAY p_geography_unit_ids LOOP
        IF NOT EXISTS (
            SELECT 1 FROM catalog.geography_units
            WHERE id = v_uid AND country_id = v_country_id
        ) THEN
            RAISE EXCEPTION 'Geography unit % does not belong to the same country', v_uid;
        END IF;
    END LOOP;

    -- Replace all mappings atomically
    DELETE FROM catalog.postal_code_geographies WHERE postal_code_id = p_postal_code_id;

    INSERT INTO catalog.postal_code_geographies(postal_code_id, geography_unit_id, country_id)
    SELECT p_postal_code_id, UNNEST(p_geography_unit_ids), v_country_id;

    PERFORM public.rpc_write_audit(
        p_staff_id, 'SET_MAPPINGS', 'catalog.postal_code_geographies', p_postal_code_id,
        pg_catalog.jsonb_build_object('geography_unit_ids', p_geography_unit_ids::TEXT[])
    );
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_set_postal_mappings(pg_catalog.uuid, pg_catalog.uuid[], pg_catalog.uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.rpc_set_postal_mappings(pg_catalog.uuid, pg_catalog.uuid[], pg_catalog.uuid) FROM anon;
REVOKE ALL ON FUNCTION public.rpc_set_postal_mappings(pg_catalog.uuid, pg_catalog.uuid[], pg_catalog.uuid) FROM authenticated;
GRANT  ALL ON FUNCTION public.rpc_set_postal_mappings(pg_catalog.uuid, pg_catalog.uuid[], pg_catalog.uuid) TO service_role;
