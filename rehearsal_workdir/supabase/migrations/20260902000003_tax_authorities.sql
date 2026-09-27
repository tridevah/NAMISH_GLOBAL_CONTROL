-- Migration 000017: Tax Authorities Implementation

CREATE EXTENSION IF NOT EXISTS btree_gist;

-- 1. Tax Authorities
CREATE TABLE catalog.tax_authorities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    country_id UUID NOT NULL REFERENCES catalog.countries(id),
    jurisdiction_id UUID NOT NULL REFERENCES catalog.jurisdictions(id),
    tax_type TEXT NOT NULL CHECK (tax_type IN ('GST', 'VAT', 'SALES_TAX', 'WITHHOLDING', 'TDS', 'CUSTOMS', 'EXCISE')),
    authority_name TEXT NOT NULL,
    official_website TEXT,
    provenance_reference TEXT,
    status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE')),
    effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    effective_to TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    -- Gist to prevent overlapping authority for same country/jurisdiction and tax type
    EXCLUDE USING gist (
        country_id WITH =,
        jurisdiction_id WITH =,
        tax_type WITH =,
        tstzrange(effective_from, COALESCE(effective_to, 'infinity'), '[]') WITH &&
    )
);

ALTER TABLE catalog.tax_authorities ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog.tax_authorities FORCE ROW LEVEL SECURITY;
GRANT ALL ON catalog.tax_authorities TO service_role;

-- Update the RPC to allow tax_authorities and jurisdictions
CREATE OR REPLACE FUNCTION catalog.rpc_mutate_tax_entity(
    p_table_name pg_catalog.text,
    p_action     pg_catalog.text,
    p_payload    pg_catalog.jsonb,
    p_actor_id   pg_catalog.uuid
) RETURNS pg_catalog.jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO pg_catalog
AS $$
DECLARE
    v_result pg_catalog.jsonb;
    v_id     pg_catalog.uuid;
    v_sql    pg_catalog.text;
    v_cols   pg_catalog.text;
    v_vals   pg_catalog.text;
    v_set    pg_catalog.text;
BEGIN
    IF p_table_name NOT IN (
        'tax_regimes', 'tax_components', 'tax_codes', 'tax_rates',
        'tax_rate_component_sets', 'tax_rate_component_lines',
        'hsn_sac', 'hsn_sac_tax_codes',
        'currencies',
        'tax_authorities', 'jurisdictions'
    ) THEN
        RAISE EXCEPTION 'Invalid table: %', p_table_name;
    END IF;

    IF p_action = 'INSERT' THEN
        SELECT pg_catalog.string_agg(pg_catalog.quote_ident(key), ', '),
               pg_catalog.string_agg('''' || pg_catalog.replace(value#>>'{}', '''', '''''') || '''', ', ')
        INTO v_cols, v_vals
        FROM pg_catalog.jsonb_each(p_payload);
        v_sql := 'INSERT INTO catalog.' || pg_catalog.quote_ident(p_table_name)
                 || ' (' || v_cols || ') VALUES (' || v_vals || ') RETURNING to_jsonb(*)';
        EXECUTE v_sql INTO v_result;
        v_id := (v_result->>'id')::pg_catalog.uuid;
    ELSIF p_action = 'UPDATE' THEN
        v_id := (p_payload->>'id')::pg_catalog.uuid;
        IF v_id IS NULL THEN
            RAISE EXCEPTION 'ID is required for UPDATE';
        END IF;
        
        SELECT pg_catalog.string_agg(
               pg_catalog.quote_ident(key) || ' = ''' || pg_catalog.replace(value#>>'{}', '''', '''''') || '''', ', ')
        INTO v_set
        FROM pg_catalog.jsonb_each(p_payload) WHERE key != 'id';
        
        v_sql := 'UPDATE catalog.' || pg_catalog.quote_ident(p_table_name)
                 || ' SET ' || v_set || ' WHERE id = ''' || v_id || ''' RETURNING to_jsonb(*)';
        EXECUTE v_sql INTO v_result;
    ELSIF p_action = 'DELETE' THEN
        v_id := (p_payload->>'id')::pg_catalog.uuid;
        v_sql := 'DELETE FROM catalog.' || pg_catalog.quote_ident(p_table_name)
                 || ' WHERE id = ''' || v_id || ''' RETURNING to_jsonb(*)';
        EXECUTE v_sql INTO v_result;
    ELSE
        RAISE EXCEPTION 'Invalid action: %', p_action;
    END IF;

    INSERT INTO audit.logs (actor_id, action, resource, resource_id, metadata)
    VALUES (p_actor_id, 'TAX_MUTATION_' || p_action, 'catalog.' || p_table_name, v_id, p_payload);

    RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION catalog.rpc_mutate_tax_entity(
    pg_catalog.text, pg_catalog.text, pg_catalog.jsonb, pg_catalog.uuid
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION catalog.rpc_mutate_tax_entity(
    pg_catalog.text, pg_catalog.text, pg_catalog.jsonb, pg_catalog.uuid
) TO service_role;
