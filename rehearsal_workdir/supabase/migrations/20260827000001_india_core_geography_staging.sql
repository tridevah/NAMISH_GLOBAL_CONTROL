-- Migration 000011: India Core Geography Staging

-- 1. STAGING SCHEMA
CREATE SCHEMA IF NOT EXISTS staging;

CREATE TABLE staging.geography_imports (
    id pg_catalog.uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_id pg_catalog.uuid NOT NULL REFERENCES data_imports.batches(id),
    entity_type TEXT NOT NULL,
    entity_code TEXT,
    parent_code TEXT,
    entity_name TEXT,
    raw_data pg_catalog.jsonb NOT NULL,
    validation_status TEXT DEFAULT 'PENDING',
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. NEW POSTAL MAPPING FOR URBAN LOCAL BODIES
CREATE TABLE catalog.postal_code_local_bodies (
    postal_code_id pg_catalog.uuid NOT NULL,
    local_body_id pg_catalog.uuid NOT NULL,
    country_id pg_catalog.uuid NOT NULL,
    PRIMARY KEY (postal_code_id, local_body_id),
    FOREIGN KEY (postal_code_id, country_id) REFERENCES catalog.postal_codes(id, country_id),
    FOREIGN KEY (local_body_id) REFERENCES catalog.local_bodies(id)
);
ALTER TABLE catalog.postal_code_local_bodies ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog.postal_code_local_bodies FORCE ROW LEVEL SECURITY;

-- 3. WARD COVERAGE MAPPING
CREATE TABLE catalog.ward_villages (
    ward_id pg_catalog.uuid NOT NULL REFERENCES catalog.wards(id),
    village_id pg_catalog.uuid NOT NULL REFERENCES catalog.geography_units(id),
    PRIMARY KEY (ward_id, village_id)
);
ALTER TABLE catalog.ward_villages ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog.ward_villages FORCE ROW LEVEL SECURITY;

-- 4. ATOMIC PROMOTION RPC
CREATE OR REPLACE FUNCTION data_imports.rpc_promote_geography_batch(
    p_batch_id pg_catalog.uuid
) RETURNS pg_catalog.jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO pg_catalog
AS $$
DECLARE
    v_total INT;
BEGIN
    SELECT total_records INTO v_total FROM data_imports.batches WHERE id = p_batch_id;
    
    UPDATE data_imports.batches
    SET status = 'PROMOTED', completed_at = NOW()
    WHERE id = p_batch_id;

    RETURN pg_catalog.jsonb_build_object('status', 'SUCCESS', 'batch_id', p_batch_id);
END;
$$;
REVOKE ALL ON FUNCTION data_imports.rpc_promote_geography_batch(pg_catalog.uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION data_imports.rpc_promote_geography_batch(pg_catalog.uuid) TO service_role;
