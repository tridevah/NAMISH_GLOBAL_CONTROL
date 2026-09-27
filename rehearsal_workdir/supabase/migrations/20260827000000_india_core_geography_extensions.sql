-- Migration 000010: India Core Geography Extensions
-- Adds canonical tables for Development Blocks, Local Bodies, and Wards.

-- ============================================================
-- 1. ENUMS & SCHEMAS
-- ============================================================
CREATE TYPE catalog.local_body_type AS ENUM (
    'PRI_DISTRICT',
    'PRI_INTERMEDIATE',
    'PRI_GRAM_PANCHAYAT',
    'URBAN',
    'TRADITIONAL'
);

CREATE SCHEMA IF NOT EXISTS data_imports;

-- ============================================================
-- 2. IMPORT BATCHES TRACKING
-- ============================================================
CREATE TABLE data_imports.releases (
    id pg_catalog.uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    release_name TEXT NOT NULL UNIQUE,
    source_uri TEXT NOT NULL,
    sha256_hash TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'PENDING',
    started_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

CREATE TABLE data_imports.batches (
    id pg_catalog.uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    release_id pg_catalog.uuid NOT NULL REFERENCES data_imports.releases(id),
    entity_type TEXT NOT NULL,
    total_records INT NOT NULL DEFAULT 0,
    successful_records INT NOT NULL DEFAULT 0,
    failed_records INT NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'PENDING',
    started_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    UNIQUE(release_id, entity_type)
);

CREATE TABLE data_imports.row_errors (
    id pg_catalog.uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_id pg_catalog.uuid NOT NULL REFERENCES data_imports.batches(id),
    official_code TEXT,
    row_data pg_catalog.jsonb NOT NULL,
    error_message TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 3. CORE GEOGRAPHY EXTENSION TABLES
-- ============================================================

-- DEVELOPMENT BLOCKS
CREATE TABLE catalog.development_blocks (
    id pg_catalog.uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    district_id pg_catalog.uuid NOT NULL REFERENCES catalog.geography_units(id),
    official_code TEXT NOT NULL UNIQUE,
    official_name TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by pg_catalog.uuid REFERENCES platform.platform_staff(id),
    updated_by pg_catalog.uuid REFERENCES platform.platform_staff(id)
);
ALTER TABLE catalog.development_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog.development_blocks FORCE ROW LEVEL SECURITY;

CREATE TABLE catalog.block_villages (
    block_id pg_catalog.uuid NOT NULL REFERENCES catalog.development_blocks(id),
    village_id pg_catalog.uuid NOT NULL REFERENCES catalog.geography_units(id),
    PRIMARY KEY (block_id, village_id)
);
ALTER TABLE catalog.block_villages ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog.block_villages FORCE ROW LEVEL SECURITY;

-- LOCAL BODIES (PRI, URBAN, TRADITIONAL)
CREATE TABLE catalog.local_bodies (
    id pg_catalog.uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    state_id pg_catalog.uuid NOT NULL REFERENCES catalog.geography_units(id),
    parent_local_body_id pg_catalog.uuid REFERENCES catalog.local_bodies(id),
    body_type catalog.local_body_type NOT NULL,
    official_code TEXT NOT NULL UNIQUE,
    official_name TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by pg_catalog.uuid REFERENCES platform.platform_staff(id),
    updated_by pg_catalog.uuid REFERENCES platform.platform_staff(id)
);
ALTER TABLE catalog.local_bodies ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog.local_bodies FORCE ROW LEVEL SECURITY;

CREATE TABLE catalog.local_body_villages (
    local_body_id pg_catalog.uuid NOT NULL REFERENCES catalog.local_bodies(id),
    village_id pg_catalog.uuid NOT NULL REFERENCES catalog.geography_units(id),
    PRIMARY KEY (local_body_id, village_id)
);
ALTER TABLE catalog.local_body_villages ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog.local_body_villages FORCE ROW LEVEL SECURITY;

-- WARDS
CREATE TABLE catalog.wards (
    id pg_catalog.uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    local_body_id pg_catalog.uuid NOT NULL REFERENCES catalog.local_bodies(id),
    official_code TEXT NOT NULL UNIQUE,
    ward_number TEXT NOT NULL,
    official_name TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by pg_catalog.uuid REFERENCES platform.platform_staff(id),
    updated_by pg_catalog.uuid REFERENCES platform.platform_staff(id)
);
ALTER TABLE catalog.wards ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog.wards FORCE ROW LEVEL SECURITY;

-- ============================================================
-- 4. RPCS FOR CORE EXTENSIONS (GATEWAY)
-- ============================================================
-- To ensure strict security boundaries, these RPCs enforce search_path=pg_catalog
-- and are restricted to service_role.
-- ============================================================
-- 4. RPCS FOR CORE EXTENSIONS (GATEWAY)
-- ============================================================

CREATE OR REPLACE FUNCTION public.rpc_get_development_blocks()
RETURNS SETOF catalog.development_blocks AS $$
BEGIN
    RETURN QUERY SELECT * FROM catalog.development_blocks ORDER BY official_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path TO pg_catalog;
REVOKE ALL ON FUNCTION public.rpc_get_development_blocks() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_get_development_blocks() TO service_role;

CREATE OR REPLACE FUNCTION public.rpc_get_local_bodies()
RETURNS SETOF catalog.local_bodies AS $$
BEGIN
    RETURN QUERY SELECT * FROM catalog.local_bodies ORDER BY official_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path TO pg_catalog;
REVOKE ALL ON FUNCTION public.rpc_get_local_bodies() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_get_local_bodies() TO service_role;

CREATE OR REPLACE FUNCTION public.rpc_get_wards()
RETURNS SETOF catalog.wards AS $$
BEGIN
    RETURN QUERY SELECT * FROM catalog.wards ORDER BY ward_number, official_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path TO pg_catalog;
REVOKE ALL ON FUNCTION public.rpc_get_wards() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_get_wards() TO service_role;

