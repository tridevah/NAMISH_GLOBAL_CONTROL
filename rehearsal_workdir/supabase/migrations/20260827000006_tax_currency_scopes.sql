-- Migration 000016: Tax Phase 2B-A Geography/Currency Scopes

CREATE EXTENSION IF NOT EXISTS btree_gist;

-- 1. Applicability Scopes
CREATE TABLE catalog.applicability_scopes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    country_id UUID NOT NULL REFERENCES catalog.countries(id),
    scope_type TEXT NOT NULL CHECK (scope_type IN ('COUNTRY_WIDE', 'GEOGRAPHIC')),
    priority INT NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE')),
    effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    effective_to TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE catalog.applicability_scopes ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog.applicability_scopes FORCE ROW LEVEL SECURITY;
GRANT ALL ON catalog.applicability_scopes TO service_role;

-- 2. Applicability Scope Geographies
CREATE TABLE catalog.applicability_scope_geographies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    scope_id UUID NOT NULL REFERENCES catalog.applicability_scopes(id),
    geography_unit_id UUID NOT NULL REFERENCES catalog.geography_units(id),
    action TEXT NOT NULL CHECK (action IN ('INCLUDE', 'EXCLUDE')),
    includes_descendants BOOLEAN NOT NULL DEFAULT true,
    effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    effective_to TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    EXCLUDE USING gist (scope_id WITH =, geography_unit_id WITH =, tstzrange(effective_from, COALESCE(effective_to, 'infinity'), '[]') WITH &&)
);
ALTER TABLE catalog.applicability_scope_geographies ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog.applicability_scope_geographies FORCE ROW LEVEL SECURITY;
GRANT ALL ON catalog.applicability_scope_geographies TO service_role;

-- Trigger to deny cross-country mapping in scope geographies
CREATE OR REPLACE FUNCTION catalog.check_cross_country_scope_geo()
RETURNS trigger AS $$
DECLARE
    v_scope_country UUID;
    v_geo_country UUID;
BEGIN
    SELECT country_id INTO v_scope_country FROM catalog.applicability_scopes WHERE id = NEW.scope_id;
    SELECT country_id INTO v_geo_country FROM catalog.geography_units WHERE id = NEW.geography_unit_id;
    
    IF v_scope_country != v_geo_country THEN
        RAISE EXCEPTION 'Cross-country assignment denied. Scope country does not match Geography country.';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER prevent_cross_country_scope_geo
BEFORE INSERT OR UPDATE ON catalog.applicability_scope_geographies
FOR EACH ROW EXECUTE FUNCTION catalog.check_cross_country_scope_geo();

-- 3. Canonical Currencies (Modifying existing table)
ALTER TABLE catalog.currencies RENAME COLUMN code TO iso_alpha_code;
ALTER TABLE catalog.currencies RENAME COLUMN symbol TO default_symbol;
ALTER TABLE catalog.currencies ADD COLUMN iso_numeric_code TEXT;
ALTER TABLE catalog.currencies ADD COLUMN native_symbol TEXT;
ALTER TABLE catalog.currencies ADD COLUMN minor_units INT DEFAULT 2;
ALTER TABLE catalog.currencies ADD COLUMN status TEXT DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE'));
ALTER TABLE catalog.currencies ADD COLUMN effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW();
ALTER TABLE catalog.currencies ADD COLUMN effective_to TIMESTAMPTZ;
ALTER TABLE catalog.currencies ADD CONSTRAINT currencies_iso_alpha_code_key UNIQUE (iso_alpha_code);
-- Note: 'default_symbol' and 'native_symbol' intentionally NOT unique (Unicode support enabled naturally via TEXT).

-- 4. Currency Scope Assignments
CREATE TABLE catalog.currency_scope_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    currency_id UUID NOT NULL REFERENCES catalog.currencies(id),
    applicability_scope_id UUID NOT NULL REFERENCES catalog.applicability_scopes(id),
    usage TEXT NOT NULL CHECK (usage IN ('LEGAL_TENDER', 'PRIMARY', 'ACCOUNTING', 'SETTLEMENT')),
    display_symbol TEXT,
    symbol_position TEXT CHECK (symbol_position IN ('BEFORE_AMOUNT', 'AFTER_AMOUNT')),
    space_between_symbol_and_amount BOOLEAN DEFAULT false,
    priority INT NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE')),
    effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    effective_to TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    -- Only one overlapping PRIMARY currency per scope
    EXCLUDE USING gist (
        applicability_scope_id WITH =,
        usage WITH =
    ) WHERE (usage = 'PRIMARY')
);
ALTER TABLE catalog.currency_scope_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog.currency_scope_assignments FORCE ROW LEVEL SECURITY;
GRANT ALL ON catalog.currency_scope_assignments TO service_role;

-- 5. Attach Tax to Shared Applicability Scopes
ALTER TABLE catalog.tax_regimes ADD COLUMN country_id UUID REFERENCES catalog.countries(id);
-- Ensure no legacy rows
ALTER TABLE catalog.tax_regimes ALTER COLUMN country_id SET NOT NULL;

ALTER TABLE catalog.jurisdictions ADD COLUMN country_id UUID REFERENCES catalog.countries(id);
ALTER TABLE catalog.jurisdictions ADD COLUMN applicability_scope_id UUID REFERENCES catalog.applicability_scopes(id);
ALTER TABLE catalog.jurisdictions ALTER COLUMN country_id SET NOT NULL;
ALTER TABLE catalog.jurisdictions ALTER COLUMN applicability_scope_id SET NOT NULL;

-- Trigger to deny cross-country mapping in tax jurisdictions
CREATE OR REPLACE FUNCTION catalog.check_cross_country_tax()
RETURNS trigger AS $$
DECLARE
    v_scope_country UUID;
BEGIN
    SELECT country_id INTO v_scope_country FROM catalog.applicability_scopes WHERE id = NEW.applicability_scope_id;
    
    IF v_scope_country != NEW.country_id THEN
        RAISE EXCEPTION 'Cross-country assignment denied. Jurisdiction country does not match Scope country.';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER prevent_cross_country_jurisdictions
BEFORE INSERT OR UPDATE ON catalog.jurisdictions
FOR EACH ROW EXECUTE FUNCTION catalog.check_cross_country_tax();

-- 6. RPCs for Resolvers

-- Find parent hierarchy helper
CREATE OR REPLACE FUNCTION catalog.get_geography_lineage(p_unit_id UUID)
RETURNS TABLE (geography_unit_id UUID) AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE lineage AS (
        SELECT id, parent_geography_unit_id
        FROM catalog.geography_units
        WHERE id = p_unit_id
        UNION ALL
        SELECT g.id, g.parent_geography_unit_id
        FROM catalog.geography_units g
        INNER JOIN lineage l ON g.id = l.parent_geography_unit_id
    )
    SELECT id FROM lineage;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO pg_catalog;

-- Resolve Currencies
CREATE OR REPLACE FUNCTION catalog.rpc_resolve_currency_by_geography(
    p_geography_id pg_catalog.uuid,
    p_date pg_catalog.timestamptz DEFAULT NOW()
) RETURNS pg_catalog.jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO pg_catalog
AS $$
DECLARE
    v_country_id pg_catalog.uuid;
    v_result pg_catalog.jsonb;
BEGIN
    SELECT country_id INTO v_country_id FROM catalog.geography_units WHERE id = p_geography_id;

    WITH valid_scopes AS (
        -- Get COUNTRY_WIDE scopes for this country
        SELECT id FROM catalog.applicability_scopes
        WHERE country_id = v_country_id AND scope_type = 'COUNTRY_WIDE'
          AND status = 'ACTIVE'
          AND p_date >= effective_from AND (effective_to IS NULL OR p_date <= effective_to)
        UNION
        -- Get GEOGRAPHIC scopes covering this unit's lineage
        SELECT s.id 
        FROM catalog.applicability_scopes s
        JOIN catalog.applicability_scope_geographies sg ON s.id = sg.scope_id
        WHERE s.country_id = v_country_id AND s.scope_type = 'GEOGRAPHIC'
          AND s.status = 'ACTIVE'
          AND p_date >= s.effective_from AND (s.effective_to IS NULL OR p_date <= s.effective_to)
          AND sg.action = 'INCLUDE'
          AND p_date >= sg.effective_from AND (sg.effective_to IS NULL OR p_date <= sg.effective_to)
          AND (
            sg.geography_unit_id = p_geography_id OR 
            (sg.includes_descendants = true AND sg.geography_unit_id IN (SELECT geography_unit_id FROM catalog.get_geography_lineage(p_geography_id)))
          )
    )
    SELECT pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
            'currency_id', c.id,
            'iso_alpha_code', c.iso_alpha_code,
            'name', c.name,
            'usage', a.usage,
            'symbol', COALESCE(a.display_symbol, c.default_symbol),
            'position', a.symbol_position,
            'space', a.space_between_symbol_and_amount
        )
    ) INTO v_result
    FROM catalog.currency_scope_assignments a
    JOIN catalog.currencies c ON a.currency_id = c.id
    JOIN valid_scopes vs ON a.applicability_scope_id = vs.id
    WHERE a.status = 'ACTIVE'
      AND p_date >= a.effective_from AND (a.effective_to IS NULL OR p_date <= a.effective_to);

    RETURN COALESCE(v_result, '[]'::pg_catalog.jsonb);
END;
$$;
REVOKE ALL ON FUNCTION catalog.rpc_resolve_currency_by_geography(pg_catalog.uuid, pg_catalog.timestamptz) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION catalog.rpc_resolve_currency_by_geography(pg_catalog.uuid, pg_catalog.timestamptz) TO service_role;

-- Resolve Tax Jurisdictions
CREATE OR REPLACE FUNCTION catalog.rpc_resolve_tax_jurisdictions(
    p_geography_id pg_catalog.uuid,
    p_date pg_catalog.timestamptz DEFAULT NOW()
) RETURNS pg_catalog.jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO pg_catalog
AS $$
DECLARE
    v_country_id pg_catalog.uuid;
    v_result pg_catalog.jsonb;
BEGIN
    SELECT country_id INTO v_country_id FROM catalog.geography_units WHERE id = p_geography_id;

    WITH valid_scopes AS (
        SELECT id FROM catalog.applicability_scopes
        WHERE country_id = v_country_id AND scope_type = 'COUNTRY_WIDE'
          AND status = 'ACTIVE'
          AND p_date >= effective_from AND (effective_to IS NULL OR p_date <= effective_to)
        UNION
        SELECT s.id 
        FROM catalog.applicability_scopes s
        JOIN catalog.applicability_scope_geographies sg ON s.id = sg.scope_id
        WHERE s.country_id = v_country_id AND s.scope_type = 'GEOGRAPHIC'
          AND s.status = 'ACTIVE'
          AND p_date >= s.effective_from AND (s.effective_to IS NULL OR p_date <= s.effective_to)
          AND sg.action = 'INCLUDE'
          AND p_date >= sg.effective_from AND (sg.effective_to IS NULL OR p_date <= sg.effective_to)
          AND (
            sg.geography_unit_id = p_geography_id OR 
            (sg.includes_descendants = true AND sg.geography_unit_id IN (SELECT geography_unit_id FROM catalog.get_geography_lineage(p_geography_id)))
          )
    )
    SELECT pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
            'jurisdiction_id', j.id,
            'jurisdiction_code', j.code,
            'jurisdiction_name', j.name
        )
    ) INTO v_result
    FROM catalog.jurisdictions j
    JOIN valid_scopes vs ON j.applicability_scope_id = vs.id;

    RETURN COALESCE(v_result, '[]'::pg_catalog.jsonb);
END;
$$;
REVOKE ALL ON FUNCTION catalog.rpc_resolve_tax_jurisdictions(pg_catalog.uuid, pg_catalog.timestamptz) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION catalog.rpc_resolve_tax_jurisdictions(pg_catalog.uuid, pg_catalog.timestamptz) TO service_role;
