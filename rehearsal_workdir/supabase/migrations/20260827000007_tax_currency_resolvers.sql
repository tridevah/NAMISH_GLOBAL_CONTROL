-- Migration 000017: Update Resolvers to explicit country + geography signatures

-- Drop the old ones (from 000016) because signatures changed
DROP FUNCTION IF EXISTS catalog.rpc_resolve_currency_by_geography(uuid, timestamptz);
DROP FUNCTION IF EXISTS catalog.rpc_resolve_tax_jurisdictions(uuid, timestamptz);

-- Resolve Currencies
CREATE OR REPLACE FUNCTION catalog.rpc_resolve_currency_by_geography(
    p_country_id pg_catalog.uuid,
    p_geography_unit_id pg_catalog.uuid DEFAULT NULL,
    p_as_of_date pg_catalog.timestamptz DEFAULT NOW()
) RETURNS pg_catalog.jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO pg_catalog
AS $$
DECLARE
    v_actual_country pg_catalog.uuid;
    v_result pg_catalog.jsonb;
BEGIN
    -- Cross-country validation
    IF p_geography_unit_id IS NOT NULL THEN
        SELECT country_id INTO v_actual_country FROM catalog.geography_units WHERE id = p_geography_unit_id;
        IF v_actual_country != p_country_id THEN
            RAISE EXCEPTION 'Cross-country request denied. Provided Geography unit does not belong to provided Country.';
        END IF;
    END IF;

    WITH valid_scopes AS (
        -- Get COUNTRY_WIDE scopes for this country
        SELECT id, priority FROM catalog.applicability_scopes
        WHERE country_id = p_country_id AND scope_type = 'COUNTRY_WIDE'
          AND status = 'ACTIVE'
          AND p_as_of_date >= effective_from AND (effective_to IS NULL OR p_as_of_date <= effective_to)
        UNION
        -- Get GEOGRAPHIC scopes covering this unit's lineage
        SELECT s.id, s.priority
        FROM catalog.applicability_scopes s
        JOIN catalog.applicability_scope_geographies sg ON s.id = sg.scope_id
        WHERE s.country_id = p_country_id AND s.scope_type = 'GEOGRAPHIC'
          AND p_geography_unit_id IS NOT NULL
          AND s.status = 'ACTIVE'
          AND p_as_of_date >= s.effective_from AND (s.effective_to IS NULL OR p_as_of_date <= s.effective_to)
          AND sg.action = 'INCLUDE'
          AND p_as_of_date >= sg.effective_from AND (sg.effective_to IS NULL OR p_as_of_date <= sg.effective_to)
          AND (
            sg.geography_unit_id = p_geography_unit_id OR 
            (sg.includes_descendants = true AND sg.geography_unit_id IN (SELECT geography_unit_id FROM catalog.get_geography_lineage(p_geography_unit_id)))
          )
        -- Explicit EXCLUDE removal
        EXCEPT
        SELECT s.id, s.priority
        FROM catalog.applicability_scopes s
        JOIN catalog.applicability_scope_geographies sg ON s.id = sg.scope_id
        WHERE p_geography_unit_id IS NOT NULL
          AND sg.action = 'EXCLUDE'
          AND p_as_of_date >= sg.effective_from AND (sg.effective_to IS NULL OR p_as_of_date <= sg.effective_to)
          AND (
            sg.geography_unit_id = p_geography_unit_id OR 
            (sg.includes_descendants = true AND sg.geography_unit_id IN (SELECT geography_unit_id FROM catalog.get_geography_lineage(p_geography_unit_id)))
          )
    )
    SELECT pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
            'currency_id', c.id,
            'iso_alpha_code', c.iso_alpha_code,
            'iso_numeric_code', c.iso_numeric_code,
            'name', c.name,
            'minor_units', c.minor_units,
            'usage', a.usage,
            'symbol', COALESCE(a.display_symbol, c.default_symbol, c.native_symbol),
            'position', a.symbol_position,
            'space', a.space_between_symbol_and_amount,
            'priority', GREATEST(vs.priority, a.priority)
        )
        ORDER BY GREATEST(vs.priority, a.priority) DESC
    ) INTO v_result
    FROM catalog.currency_scope_assignments a
    JOIN catalog.currencies c ON a.currency_id = c.id
    JOIN valid_scopes vs ON a.applicability_scope_id = vs.id
    WHERE a.status = 'ACTIVE'
      AND p_as_of_date >= a.effective_from AND (a.effective_to IS NULL OR p_as_of_date <= a.effective_to);

    RETURN COALESCE(v_result, '[]'::pg_catalog.jsonb);
END;
$$;

REVOKE ALL ON FUNCTION catalog.rpc_resolve_currency_by_geography(pg_catalog.uuid, pg_catalog.uuid, pg_catalog.timestamptz) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION catalog.rpc_resolve_currency_by_geography(pg_catalog.uuid, pg_catalog.uuid, pg_catalog.timestamptz) TO service_role;


-- Resolve Tax Jurisdictions
CREATE OR REPLACE FUNCTION catalog.rpc_resolve_tax_jurisdictions(
    p_country_id pg_catalog.uuid,
    p_geography_unit_id pg_catalog.uuid DEFAULT NULL,
    p_as_of_date pg_catalog.timestamptz DEFAULT NOW()
) RETURNS pg_catalog.jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO pg_catalog
AS $$
DECLARE
    v_actual_country pg_catalog.uuid;
    v_result pg_catalog.jsonb;
BEGIN
    -- Cross-country validation
    IF p_geography_unit_id IS NOT NULL THEN
        SELECT country_id INTO v_actual_country FROM catalog.geography_units WHERE id = p_geography_unit_id;
        IF v_actual_country != p_country_id THEN
            RAISE EXCEPTION 'Cross-country request denied. Provided Geography unit does not belong to provided Country.';
        END IF;
    END IF;

    WITH valid_scopes AS (
        SELECT id, priority FROM catalog.applicability_scopes
        WHERE country_id = p_country_id AND scope_type = 'COUNTRY_WIDE'
          AND status = 'ACTIVE'
          AND p_as_of_date >= effective_from AND (effective_to IS NULL OR p_as_of_date <= effective_to)
        UNION
        SELECT s.id, s.priority
        FROM catalog.applicability_scopes s
        JOIN catalog.applicability_scope_geographies sg ON s.id = sg.scope_id
        WHERE s.country_id = p_country_id AND s.scope_type = 'GEOGRAPHIC'
          AND p_geography_unit_id IS NOT NULL
          AND s.status = 'ACTIVE'
          AND p_as_of_date >= s.effective_from AND (s.effective_to IS NULL OR p_as_of_date <= s.effective_to)
          AND sg.action = 'INCLUDE'
          AND p_as_of_date >= sg.effective_from AND (sg.effective_to IS NULL OR p_as_of_date <= sg.effective_to)
          AND (
            sg.geography_unit_id = p_geography_unit_id OR 
            (sg.includes_descendants = true AND sg.geography_unit_id IN (SELECT geography_unit_id FROM catalog.get_geography_lineage(p_geography_unit_id)))
          )
        EXCEPT
        SELECT s.id, s.priority
        FROM catalog.applicability_scopes s
        JOIN catalog.applicability_scope_geographies sg ON s.id = sg.scope_id
        WHERE p_geography_unit_id IS NOT NULL
          AND sg.action = 'EXCLUDE'
          AND p_as_of_date >= sg.effective_from AND (sg.effective_to IS NULL OR p_as_of_date <= sg.effective_to)
          AND (
            sg.geography_unit_id = p_geography_unit_id OR 
            (sg.includes_descendants = true AND sg.geography_unit_id IN (SELECT geography_unit_id FROM catalog.get_geography_lineage(p_geography_unit_id)))
          )
    )
    SELECT pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
            'jurisdiction_id', j.id,
            'jurisdiction_code', j.code,
            'jurisdiction_name', j.name,
            'priority', vs.priority
        )
        ORDER BY vs.priority DESC
    ) INTO v_result
    FROM catalog.jurisdictions j
    JOIN valid_scopes vs ON j.applicability_scope_id = vs.id;

    RETURN COALESCE(v_result, '[]'::pg_catalog.jsonb);
END;
$$;

REVOKE ALL ON FUNCTION catalog.rpc_resolve_tax_jurisdictions(pg_catalog.uuid, pg_catalog.uuid, pg_catalog.timestamptz) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION catalog.rpc_resolve_tax_jurisdictions(pg_catalog.uuid, pg_catalog.uuid, pg_catalog.timestamptz) TO service_role;
