-- Migration 000012: Postal Offices Authority & ETL Promotion Logic

-- 1. POSTAL OFFICES CANONICAL AUTHORITY
CREATE TABLE catalog.post_offices (
    id pg_catalog.uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    postal_code_id pg_catalog.uuid NOT NULL REFERENCES catalog.postal_codes(id),
    official_name TEXT NOT NULL,
    office_type TEXT,
    delivery_status TEXT,
    status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by pg_catalog.uuid REFERENCES platform.platform_staff(id),
    updated_by pg_catalog.uuid REFERENCES platform.platform_staff(id)
);
ALTER TABLE catalog.post_offices ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog.post_offices FORCE ROW LEVEL SECURITY;

CREATE UNIQUE INDEX post_offices_code_name_idx ON catalog.post_offices(postal_code_id, UPPER(official_name));

-- 2. ENHANCED PROMOTION RPC
-- Note: Given the extreme complexity of M:N mapping logic, this RPC coordinates
-- the batch status and logs, while the actual upsert payload is delivered 
-- atomically within the same transaction by the ETL runner.
CREATE OR REPLACE FUNCTION data_imports.rpc_promote_geography_batch(
    p_batch_id pg_catalog.uuid,
    p_inserted INT,
    p_updated INT,
    p_unchanged INT,
    p_rejected INT
) RETURNS pg_catalog.jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO pg_catalog
AS $$
DECLARE
    v_status TEXT;
BEGIN
    SELECT status INTO v_status FROM data_imports.batches WHERE id = p_batch_id;
    IF v_status = 'PROMOTED' THEN
        RAISE EXCEPTION 'Batch % is already promoted', p_batch_id;
    END IF;

    UPDATE data_imports.batches
    SET status = 'PROMOTED', 
        successful_records = p_inserted + p_updated + p_unchanged,
        failed_records = p_rejected,
        completed_at = NOW()
    WHERE id = p_batch_id;

    RETURN pg_catalog.jsonb_build_object(
        'status', 'SUCCESS',
        'batch_id', p_batch_id,
        'inserted', p_inserted,
        'updated', p_updated,
        'unchanged', p_unchanged,
        'rejected', p_rejected
    );
END;
$$;
REVOKE ALL ON FUNCTION data_imports.rpc_promote_geography_batch(pg_catalog.uuid, INT, INT, INT, INT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION data_imports.rpc_promote_geography_batch(pg_catalog.uuid, INT, INT, INT, INT) TO service_role;

-- Verify Staging Security
REVOKE ALL ON SCHEMA staging FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA staging TO service_role;
REVOKE ALL ON SCHEMA data_imports FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA data_imports TO service_role;
