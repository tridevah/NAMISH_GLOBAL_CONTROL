-- Migration 000015: Core Tax Phase 2B-A Implementation

CREATE EXTENSION IF NOT EXISTS btree_gist;

-- 1. Regimes
CREATE TABLE catalog.tax_regimes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    jurisdiction_id UUID NOT NULL REFERENCES catalog.jurisdictions(id),
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE')),
    effective_from TIMESTAMPTZ NOT NULL,
    effective_to TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(jurisdiction_id, code)
);
ALTER TABLE catalog.tax_regimes ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog.tax_regimes FORCE ROW LEVEL SECURITY;
GRANT ALL ON catalog.tax_regimes TO service_role;

-- 2. Components
CREATE TABLE catalog.tax_components (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    regime_id UUID NOT NULL REFERENCES catalog.tax_regimes(id),
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE')),
    effective_from TIMESTAMPTZ NOT NULL,
    effective_to TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(regime_id, code)
);
ALTER TABLE catalog.tax_components ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog.tax_components FORCE ROW LEVEL SECURITY;
GRANT ALL ON catalog.tax_components TO service_role;

-- 3. Modify tax_codes
ALTER TABLE catalog.tax_codes ADD COLUMN regime_id UUID REFERENCES catalog.tax_regimes(id);
-- Since counts are 0, this is safe:
ALTER TABLE catalog.tax_codes ALTER COLUMN regime_id SET NOT NULL;
ALTER TABLE catalog.tax_codes DROP CONSTRAINT IF EXISTS tax_codes_jurisdiction_id_code_key;
ALTER TABLE catalog.tax_codes ADD CONSTRAINT tax_codes_regime_id_code_key UNIQUE (regime_id, code);
ALTER TABLE catalog.tax_codes ADD COLUMN status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE'));

-- 4. Modify tax_rates
ALTER TABLE catalog.tax_rates DROP CONSTRAINT IF EXISTS prevent_overlap_tax_rates;
ALTER TABLE catalog.tax_rates ADD CONSTRAINT prevent_overlap_tax_rates
    EXCLUDE USING gist (tax_code_id WITH =, tstzrange(effective_from, COALESCE(effective_to, 'infinity'), '[]') WITH &&);

-- 5. Component Sets
CREATE TABLE catalog.tax_rate_component_sets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tax_rate_id UUID NOT NULL REFERENCES catalog.tax_rates(id),
    code TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tax_rate_id, code)
);
ALTER TABLE catalog.tax_rate_component_sets ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog.tax_rate_component_sets FORCE ROW LEVEL SECURITY;
GRANT ALL ON catalog.tax_rate_component_sets TO service_role;

-- 6. Component Lines
CREATE TABLE catalog.tax_rate_component_lines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    component_set_id UUID NOT NULL REFERENCES catalog.tax_rate_component_sets(id),
    component_id UUID NOT NULL REFERENCES catalog.tax_components(id),
    calculation_method TEXT NOT NULL CHECK (calculation_method IN ('PERCENTAGE', 'FIXED_AMOUNT')),
    percentage_value NUMERIC(12,6),
    monetary_value NUMERIC(20,6),
    quantity_basis_value NUMERIC(20,6),
    currency_code TEXT,
    uom_code TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(component_set_id, component_id),
    CONSTRAINT chk_positive_percentage CHECK (percentage_value IS NULL OR percentage_value >= 0),
    CONSTRAINT chk_positive_monetary CHECK (monetary_value IS NULL OR monetary_value >= 0),
    CONSTRAINT chk_positive_qty CHECK (quantity_basis_value IS NULL OR quantity_basis_value >= 0),
    CONSTRAINT chk_value_types CHECK (
        (calculation_method = 'PERCENTAGE' AND percentage_value IS NOT NULL AND monetary_value IS NULL AND quantity_basis_value IS NULL) OR
        (calculation_method = 'FIXED_AMOUNT' AND monetary_value IS NOT NULL)
    )
);
ALTER TABLE catalog.tax_rate_component_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog.tax_rate_component_lines FORCE ROW LEVEL SECURITY;
GRANT ALL ON catalog.tax_rate_component_lines TO service_role;

-- 7. Modify hsn_sac
ALTER TABLE catalog.hsn_sac ADD COLUMN regime_id UUID REFERENCES catalog.tax_regimes(id);
ALTER TABLE catalog.hsn_sac ADD COLUMN parent_id UUID REFERENCES catalog.hsn_sac(id);
ALTER TABLE catalog.hsn_sac ADD COLUMN status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE'));
ALTER TABLE catalog.hsn_sac ADD COLUMN effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW();
ALTER TABLE catalog.hsn_sac ADD COLUMN effective_to TIMESTAMPTZ;
ALTER TABLE catalog.hsn_sac ALTER COLUMN regime_id SET NOT NULL;
ALTER TABLE catalog.hsn_sac DROP CONSTRAINT hsn_sac_code_key; 
ALTER TABLE catalog.hsn_sac ADD CONSTRAINT hsn_sac_regime_code_key UNIQUE (regime_id, code);

-- 8. HSN/SAC Tax Assignments
CREATE TABLE catalog.hsn_sac_tax_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    hsn_sac_id UUID NOT NULL REFERENCES catalog.hsn_sac(id),
    tax_code_id UUID NOT NULL REFERENCES catalog.tax_codes(id),
    treatment TEXT NOT NULL CHECK (treatment IN ('STANDARD', 'ZERO_RATED', 'EXEMPT', 'NON_TAXABLE', 'OUT_OF_SCOPE')),
    effective_from TIMESTAMPTZ NOT NULL,
    effective_to TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    EXCLUDE USING gist (hsn_sac_id WITH =, tstzrange(effective_from, COALESCE(effective_to, 'infinity'), '[]') WITH &&)
);
ALTER TABLE catalog.hsn_sac_tax_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog.hsn_sac_tax_codes FORCE ROW LEVEL SECURITY;
GRANT ALL ON catalog.hsn_sac_tax_codes TO service_role;

-- 9. RPC Mutator (Generic) to handle tax mutations safely
CREATE OR REPLACE FUNCTION catalog.rpc_mutate_tax_entity(
    p_table_name pg_catalog.text,
    p_action pg_catalog.text,
    p_payload pg_catalog.jsonb,
    p_actor_id pg_catalog.uuid
) RETURNS pg_catalog.jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO pg_catalog
AS $$
DECLARE
    v_result pg_catalog.jsonb;
    v_id pg_catalog.uuid;
    v_sql pg_catalog.text;
    v_cols pg_catalog.text;
    v_vals pg_catalog.text;
    v_set pg_catalog.text;
BEGIN
    IF p_table_name NOT IN ('tax_regimes', 'tax_components', 'tax_codes', 'tax_rates', 'tax_rate_component_sets', 'tax_rate_component_lines', 'hsn_sac', 'hsn_sac_tax_codes') THEN
        RAISE EXCEPTION 'Invalid table';
    END IF;

    IF p_action = 'INSERT' THEN
        SELECT pg_catalog.string_agg(pg_catalog.quote_ident(key), ', '),
               pg_catalog.string_agg('''' || pg_catalog.replace(value#>>'{}', '''', '''''') || '''', ', ')
        INTO v_cols, v_vals
        FROM pg_catalog.jsonb_each(p_payload);
        
        v_sql := 'INSERT INTO catalog.' || pg_catalog.quote_ident(p_table_name) || ' (' || v_cols || ') VALUES (' || v_vals || ') RETURNING to_jsonb(*)';
        EXECUTE v_sql INTO v_result;
        v_id := (v_result->>'id')::pg_catalog.uuid;
    ELSIF p_action = 'UPDATE' THEN
        v_id := (p_payload->>'id')::pg_catalog.uuid;
        SELECT pg_catalog.string_agg(pg_catalog.quote_ident(key) || ' = ''' || pg_catalog.replace(value#>>'{}', '''', '''''') || '''', ', ')
        INTO v_set
        FROM pg_catalog.jsonb_each(p_payload) WHERE key != 'id';
        
        v_sql := 'UPDATE catalog.' || pg_catalog.quote_ident(p_table_name) || ' SET ' || v_set || ' WHERE id = ''' || v_id || ''' RETURNING to_jsonb(*)';
        EXECUTE v_sql INTO v_result;
    ELSE
        RAISE EXCEPTION 'Invalid action';
    END IF;

    -- Audit
    INSERT INTO audit.logs (actor_id, action, resource, resource_id, metadata)
    VALUES (p_actor_id, 'TAX_MUTATION_' || p_action, 'catalog.' || p_table_name, v_id, p_payload);

    RETURN v_result;
END;
$$;
REVOKE ALL ON FUNCTION catalog.rpc_mutate_tax_entity(pg_catalog.text, pg_catalog.text, pg_catalog.jsonb, pg_catalog.uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION catalog.rpc_mutate_tax_entity(pg_catalog.text, pg_catalog.text, pg_catalog.jsonb, pg_catalog.uuid) TO service_role;
