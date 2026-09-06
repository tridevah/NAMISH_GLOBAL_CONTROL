-- Migration 20260831000001_r16_core_infrastructure_clean.sql
-- R16 core infrastructure only. No Village/LOCALITY objects or data DML.

-- 1. Internal schemas and least-privilege defaults
CREATE SCHEMA IF NOT EXISTS data_imports;
CREATE SCHEMA IF NOT EXISTS staging;

REVOKE ALL ON SCHEMA data_imports, staging FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA data_imports, staging TO service_role;

-- 2. Release and batch authority
CREATE TABLE data_imports.releases (
    id pg_catalog.uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
    release_name pg_catalog.text NOT NULL UNIQUE,
    source_uri pg_catalog.text NOT NULL,
    sha256_hash pg_catalog.text NOT NULL,
    manifest_hash pg_catalog.text NOT NULL,
    status pg_catalog.text NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'STAGED', 'PROMOTED', 'FINALIZED', 'INVALIDATED', 'FAILED')),
    started_at pg_catalog.timestamptz NOT NULL DEFAULT pg_catalog.now(),
    completed_at pg_catalog.timestamptz,
    CHECK (pg_catalog.btrim(release_name) <> ''),
    CHECK (pg_catalog.btrim(source_uri) <> ''),
    CHECK (sha256_hash ~ '^[0-9A-Fa-f]{64}$'),
    CHECK (manifest_hash ~ '^[0-9A-Fa-f]{64}$')
);

CREATE TABLE data_imports.batches (
    id pg_catalog.uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
    release_id pg_catalog.uuid NOT NULL
        REFERENCES data_imports.releases(id),
    logical_batch_key pg_catalog.text NOT NULL,
    entity_type pg_catalog.text NOT NULL
        CHECK (entity_type IN ('STATE', 'DISTRICT', 'SUB_DISTRICT', 'BLOCK')),
    total_records pg_catalog.int4 NOT NULL DEFAULT 0 CHECK (total_records >= 0),
    successful_records pg_catalog.int4 NOT NULL DEFAULT 0 CHECK (successful_records >= 0),
    failed_records pg_catalog.int4 NOT NULL DEFAULT 0 CHECK (failed_records >= 0),
    status pg_catalog.text NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'EXTRACTING', 'STAGED', 'OFFICIAL_EMPTY', 'PROMOTED', 'FINALIZED', 'FAILED')),
    started_at pg_catalog.timestamptz NOT NULL DEFAULT pg_catalog.now(),
    completed_at pg_catalog.timestamptz,
    CHECK (pg_catalog.btrim(logical_batch_key) <> ''),
    UNIQUE (release_id, logical_batch_key),
    UNIQUE (id, release_id, entity_type)
);

CREATE TABLE data_imports.row_errors (
    id pg_catalog.uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
    batch_id pg_catalog.uuid NOT NULL REFERENCES data_imports.batches(id),
    official_code pg_catalog.text,
    row_data pg_catalog.jsonb NOT NULL,
    error_message pg_catalog.text NOT NULL,
    occurrence_count pg_catalog.int8 NOT NULL DEFAULT 1 CHECK (occurrence_count > 0),
    created_at pg_catalog.timestamptz NOT NULL DEFAULT pg_catalog.now()
);

CREATE TABLE data_imports.release_execution_artifacts (
    id pg_catalog.uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
    release_id pg_catalog.uuid NOT NULL REFERENCES data_imports.releases(id),
    artifact_type pg_catalog.text NOT NULL,
    artifact_payload pg_catalog.jsonb NOT NULL,
    created_at pg_catalog.timestamptz NOT NULL DEFAULT pg_catalog.now(),
    CHECK (pg_catalog.btrim(artifact_type) <> '')
);

CREATE OR REPLACE FUNCTION data_imports.trg_enforce_artifact_immutability()
RETURNS pg_catalog.trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO pg_catalog, pg_temp
AS $function$
BEGIN
    RAISE EXCEPTION 'release_execution_artifacts is append-only; % is forbidden', TG_OP;
END;
$function$;

ALTER FUNCTION data_imports.trg_enforce_artifact_immutability() OWNER TO postgres;
REVOKE ALL ON FUNCTION data_imports.trg_enforce_artifact_immutability()
    FROM PUBLIC, anon, authenticated, service_role;

CREATE TRIGGER enforce_release_execution_artifacts_immutable_rows
BEFORE UPDATE OR DELETE ON data_imports.release_execution_artifacts
FOR EACH ROW EXECUTE FUNCTION data_imports.trg_enforce_artifact_immutability();

CREATE TRIGGER enforce_release_execution_artifacts_immutable_truncate
BEFORE TRUNCATE ON data_imports.release_execution_artifacts
FOR EACH STATEMENT EXECUTE FUNCTION data_imports.trg_enforce_artifact_immutability();

-- 3. Identity-bound staging (core entities only)
CREATE TABLE staging.geography_imports (
    id pg_catalog.uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
    batch_id pg_catalog.uuid NOT NULL,
    release_id pg_catalog.uuid NOT NULL,
    entity_type pg_catalog.text NOT NULL
        CHECK (entity_type IN ('STATE', 'DISTRICT', 'SUB_DISTRICT', 'BLOCK')),
    entity_code pg_catalog.text,
    parent_code pg_catalog.text,
    entity_name pg_catalog.text,
    raw_data pg_catalog.jsonb NOT NULL,
    validation_status pg_catalog.text NOT NULL DEFAULT 'PENDING',
    error_message pg_catalog.text,
    physical_row_number pg_catalog.int4 NOT NULL CHECK (physical_row_number > 0),
    chunk_hash pg_catalog.text,
    classification pg_catalog.text NOT NULL DEFAULT 'PENDING',
    observation_identity_version pg_catalog.text NOT NULL,
    source_observation_key pg_catalog.text NOT NULL,
    physical_source_sha256 pg_catalog.text NOT NULL,
    internal_member_or_sheet pg_catalog.text NOT NULL,
    logical_output_ordinal pg_catalog.int4 NOT NULL CHECK (logical_output_ordinal >= 0),
    emitted_record_ordinal pg_catalog.int4 NOT NULL CHECK (emitted_record_ordinal > 0),
    raw_payload_sha256 pg_catalog.text NOT NULL,
    canonical_identity_key pg_catalog.text,
    observation_classification pg_catalog.text,
    importer_replay_count pg_catalog.int8 NOT NULL DEFAULT 0 CHECK (importer_replay_count >= 0),
    created_at pg_catalog.timestamptz NOT NULL DEFAULT pg_catalog.now(),
    CHECK (pg_catalog.btrim(observation_identity_version) <> ''),
    CHECK (pg_catalog.btrim(source_observation_key) <> ''),
    CHECK (pg_catalog.btrim(physical_source_sha256) <> ''),
    CHECK (pg_catalog.btrim(internal_member_or_sheet) <> ''),
    CHECK (raw_payload_sha256 ~ '^[0-9A-Fa-f]{64}$'),
    FOREIGN KEY (batch_id, release_id, entity_type)
        REFERENCES data_imports.batches(id, release_id, entity_type)
);

CREATE UNIQUE INDEX geography_imports_observation_identity_idx
ON staging.geography_imports (release_id, batch_id, source_observation_key);

CREATE OR REPLACE FUNCTION staging.trg_enforce_geography_import_identity()
RETURNS pg_catalog.trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO pg_catalog, pg_temp
AS $function$
DECLARE
    v_existing_hash pg_catalog.text;
BEGIN
    IF TG_OP = 'UPDATE' THEN
        IF ROW(
            NEW.release_id,
            NEW.batch_id,
            NEW.entity_type,
            NEW.internal_member_or_sheet,
            NEW.physical_row_number,
            NEW.logical_output_ordinal,
            NEW.emitted_record_ordinal,
            NEW.observation_identity_version,
            NEW.source_observation_key,
            NEW.physical_source_sha256,
            NEW.raw_payload_sha256,
            NEW.raw_data
        ) IS DISTINCT FROM ROW(
            OLD.release_id,
            OLD.batch_id,
            OLD.entity_type,
            OLD.internal_member_or_sheet,
            OLD.physical_row_number,
            OLD.logical_output_ordinal,
            OLD.emitted_record_ordinal,
            OLD.observation_identity_version,
            OLD.source_observation_key,
            OLD.physical_source_sha256,
            OLD.raw_payload_sha256,
            OLD.raw_data
        ) THEN
            RAISE EXCEPTION 'geography import identity and payload are immutable';
        END IF;
        RETURN NEW;
    END IF;

    SELECT gi.raw_payload_sha256
    INTO v_existing_hash
    FROM staging.geography_imports AS gi
    WHERE gi.release_id = NEW.release_id
      AND gi.batch_id = NEW.batch_id
      AND gi.source_observation_key = NEW.source_observation_key
    LIMIT 1;

    IF FOUND AND v_existing_hash IS DISTINCT FROM NEW.raw_payload_sha256 THEN
        RAISE EXCEPTION 'OBSERVATION_KEY_COLLISION';
    END IF;

    RETURN NEW;
END;
$function$;

ALTER FUNCTION staging.trg_enforce_geography_import_identity() OWNER TO postgres;
REVOKE ALL ON FUNCTION staging.trg_enforce_geography_import_identity()
    FROM PUBLIC, anon, authenticated, service_role;

CREATE TRIGGER trg_geography_imports_identity
BEFORE INSERT OR UPDATE ON staging.geography_imports
FOR EACH ROW EXECUTE FUNCTION staging.trg_enforce_geography_import_identity();

-- Internal data is readable only by the server role; mutations remain owner-only.
ALTER TABLE data_imports.releases ENABLE ROW LEVEL SECURITY;
ALTER TABLE data_imports.releases FORCE ROW LEVEL SECURITY;
ALTER TABLE data_imports.batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE data_imports.batches FORCE ROW LEVEL SECURITY;
ALTER TABLE data_imports.row_errors ENABLE ROW LEVEL SECURITY;
ALTER TABLE data_imports.row_errors FORCE ROW LEVEL SECURITY;
ALTER TABLE data_imports.release_execution_artifacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE data_imports.release_execution_artifacts FORCE ROW LEVEL SECURITY;
ALTER TABLE staging.geography_imports ENABLE ROW LEVEL SECURITY;
ALTER TABLE staging.geography_imports FORCE ROW LEVEL SECURITY;

REVOKE ALL ON ALL TABLES IN SCHEMA data_imports, staging
    FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON ALL TABLES IN SCHEMA data_imports, staging TO service_role;

-- 4. Development blocks and normalized block-district authority
CREATE TABLE catalog.development_blocks (
    id pg_catalog.uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
    official_code pg_catalog.text NOT NULL UNIQUE,
    official_name pg_catalog.text NOT NULL,
    status pg_catalog.text NOT NULL DEFAULT 'ACTIVE'
        CHECK (status IN ('ACTIVE', 'INACTIVE')),
    district_id pg_catalog.uuid REFERENCES catalog.geography_units(id),
    created_at pg_catalog.timestamptz NOT NULL DEFAULT pg_catalog.now(),
    updated_at pg_catalog.timestamptz NOT NULL DEFAULT pg_catalog.now(),
    created_by pg_catalog.uuid REFERENCES platform.platform_staff(id),
    updated_by pg_catalog.uuid REFERENCES platform.platform_staff(id),
    CHECK (pg_catalog.btrim(official_code) <> ''),
    CHECK (pg_catalog.btrim(official_name) <> '')
);

ALTER TABLE catalog.development_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog.development_blocks FORCE ROW LEVEL SECURITY;

CREATE TABLE catalog.block_districts (
    block_id pg_catalog.uuid NOT NULL REFERENCES catalog.development_blocks(id),
    district_id pg_catalog.uuid NOT NULL REFERENCES catalog.geography_units(id),
    created_at pg_catalog.timestamptz NOT NULL DEFAULT pg_catalog.now(),
    source_release_id pg_catalog.uuid REFERENCES data_imports.releases(id),
    PRIMARY KEY (block_id, district_id)
);

CREATE INDEX block_districts_district_id_idx
ON catalog.block_districts(district_id);

ALTER TABLE catalog.block_districts ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog.block_districts FORCE ROW LEVEL SECURITY;

REVOKE ALL ON catalog.development_blocks, catalog.block_districts
    FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON catalog.development_blocks, catalog.block_districts TO service_role;

CREATE OR REPLACE FUNCTION catalog.validate_block_district_relationship()
RETURNS pg_catalog.trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO pg_catalog, pg_temp
AS $function$
DECLARE
    v_district_level_key pg_catalog.text;
    v_district_country_id pg_catalog.uuid;
    v_district_state_id pg_catalog.uuid;
    v_state_level_key pg_catalog.text;
    v_state_country_id pg_catalog.uuid;
    v_cross_boundary pg_catalog.bool;
BEGIN
    PERFORM 1
    FROM catalog.development_blocks AS b
    WHERE b.id = NEW.block_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Development block % does not exist', NEW.block_id;
    END IF;

    SELECT district_level.level_key,
           district.country_id,
           district.parent_geography_unit_id,
           state_level.level_key,
           state.country_id
    INTO v_district_level_key,
         v_district_country_id,
         v_district_state_id,
         v_state_level_key,
         v_state_country_id
    FROM catalog.geography_units AS district
    JOIN catalog.geography_levels AS district_level
      ON district_level.id = district.geography_level_id
    LEFT JOIN catalog.geography_units AS state
      ON state.id = district.parent_geography_unit_id
    LEFT JOIN catalog.geography_levels AS state_level
      ON state_level.id = state.geography_level_id
    WHERE district.id = NEW.district_id;

    IF NOT FOUND OR v_district_level_key IS DISTINCT FROM 'DISTRICT' THEN
        RAISE EXCEPTION 'Block can only be linked to a DISTRICT geography unit';
    END IF;

    IF v_district_state_id IS NULL
       OR v_state_level_key IS DISTINCT FROM 'STATE_UT'
       OR v_state_country_id IS DISTINCT FROM v_district_country_id THEN
        RAISE EXCEPTION 'District % has an invalid STATE_UT parent', NEW.district_id;
    END IF;

    IF TG_OP = 'UPDATE' THEN
        SELECT pg_catalog.bool_or(
                   existing_district.country_id IS DISTINCT FROM v_district_country_id
                   OR existing_district.parent_geography_unit_id IS DISTINCT FROM v_district_state_id
               )
        INTO v_cross_boundary
        FROM catalog.block_districts AS bd
        JOIN catalog.geography_units AS existing_district
          ON existing_district.id = bd.district_id
        WHERE bd.block_id = NEW.block_id
          AND NOT (bd.block_id = OLD.block_id AND bd.district_id = OLD.district_id);
    ELSE
        SELECT pg_catalog.bool_or(
                   existing_district.country_id IS DISTINCT FROM v_district_country_id
                   OR existing_district.parent_geography_unit_id IS DISTINCT FROM v_district_state_id
               )
        INTO v_cross_boundary
        FROM catalog.block_districts AS bd
        JOIN catalog.geography_units AS existing_district
          ON existing_district.id = bd.district_id
        WHERE bd.block_id = NEW.block_id;
    END IF;

    IF COALESCE(v_cross_boundary, false) THEN
        RAISE EXCEPTION 'Block cannot span multiple States or Countries';
    END IF;

    RETURN NEW;
END;
$function$;

ALTER FUNCTION catalog.validate_block_district_relationship() OWNER TO postgres;
REVOKE ALL ON FUNCTION catalog.validate_block_district_relationship()
    FROM PUBLIC, anon, authenticated, service_role;

CREATE TRIGGER trg_validate_block_district
BEFORE INSERT OR UPDATE ON catalog.block_districts
FOR EACH ROW EXECUTE FUNCTION catalog.validate_block_district_relationship();

-- 5. Service-role-only block read gateway. Existing no-argument contract preserved.
CREATE OR REPLACE FUNCTION public.rpc_get_development_blocks()
RETURNS TABLE (
    id pg_catalog.uuid,
    district_ids pg_catalog.uuid[],
    official_code pg_catalog.text,
    official_name pg_catalog.text,
    status pg_catalog.text,
    created_at pg_catalog.timestamptz,
    updated_at pg_catalog.timestamptz,
    created_by pg_catalog.uuid,
    updated_by pg_catalog.uuid
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO pg_catalog, pg_temp
AS $function$
    SELECT b.id,
           ARRAY(
               SELECT bd.district_id
               FROM catalog.block_districts AS bd
               WHERE bd.block_id = b.id
               ORDER BY bd.district_id
           )::pg_catalog.uuid[] AS district_ids,
           b.official_code,
           b.official_name,
           b.status,
           b.created_at,
           b.updated_at,
           b.created_by,
           b.updated_by
    FROM catalog.development_blocks AS b
    ORDER BY b.official_name, b.official_code, b.id;
$function$;

ALTER FUNCTION public.rpc_get_development_blocks() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.rpc_get_development_blocks()
    FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_get_development_blocks() TO service_role;

-- 6. Hardened, paginated core-geography read gateway.
CREATE OR REPLACE FUNCTION public.rpc_get_units(
    p_country_id pg_catalog.uuid,
    p_level_id pg_catalog.uuid DEFAULT NULL,
    p_parent_id pg_catalog.uuid DEFAULT NULL,
    p_status pg_catalog.text DEFAULT NULL,
    p_search pg_catalog.text DEFAULT NULL,
    p_limit pg_catalog.int4 DEFAULT 200,
    p_offset pg_catalog.int4 DEFAULT 0
)
RETURNS pg_catalog.jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO pg_catalog, pg_temp
AS $function$
DECLARE
    v_rows pg_catalog.jsonb;
    v_total pg_catalog.int4;
    v_limit pg_catalog.int4;
    v_offset pg_catalog.int4;
BEGIN
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

    SELECT pg_catalog.jsonb_agg(
               pg_catalog.jsonb_build_object(
                   'id', page.id,
                   'country_id', page.country_id,
                   'geography_level_id', page.geography_level_id,
                   'level_number', page.level_number,
                   'level_key', page.level_key,
                   'level_label', page.level_label,
                   'parent_geography_unit_id', page.parent_geography_unit_id,
                   'parent_name', page.parent_name,
                   'official_code', page.official_code,
                   'iso_subdivision_code', page.iso_subdivision_code,
                   'official_name', page.official_name,
                   'display_name', page.display_name,
                   'status', page.status,
                   'created_at', page.created_at,
                   'updated_at', page.updated_at
               )
               ORDER BY page.level_number, page.official_code, page.id
           )
    INTO v_rows
    FROM (
        SELECT unit.id,
               unit.country_id,
               unit.geography_level_id,
               level.level_number,
               level.level_key,
               level.display_label AS level_label,
               unit.parent_geography_unit_id,
               parent.display_name AS parent_name,
               unit.official_code,
               unit.iso_subdivision_code,
               unit.official_name,
               unit.display_name,
               unit.status,
               unit.created_at,
               unit.updated_at
        FROM catalog.geography_units AS unit
        JOIN catalog.geography_levels AS level
          ON level.id = unit.geography_level_id
        LEFT JOIN catalog.geography_units AS parent
          ON parent.id = unit.parent_geography_unit_id
        WHERE unit.country_id = p_country_id
          AND level.level_key = ANY (
              ARRAY['STATE_UT', 'DISTRICT', 'SUB_DISTRICT']::pg_catalog.text[]
          )
          AND (p_level_id IS NULL OR unit.geography_level_id = p_level_id)
          AND (p_parent_id IS NULL OR unit.parent_geography_unit_id = p_parent_id)
          AND (p_status IS NULL OR unit.status = p_status)
          AND (
              p_search IS NULL
              OR pg_catalog.upper(unit.display_name) LIKE '%' || pg_catalog.upper(p_search) || '%'
              OR pg_catalog.upper(unit.official_name) LIKE '%' || pg_catalog.upper(p_search) || '%'
              OR unit.official_code ILIKE '%' || p_search || '%'
          )
        ORDER BY level.level_number, unit.official_code, unit.id
        LIMIT v_limit OFFSET v_offset
    ) AS page;

    SELECT pg_catalog.count(*)::pg_catalog.int4
    INTO v_total
    FROM catalog.geography_units AS unit
    JOIN catalog.geography_levels AS level
      ON level.id = unit.geography_level_id
    WHERE unit.country_id = p_country_id
      AND level.level_key = ANY (
          ARRAY['STATE_UT', 'DISTRICT', 'SUB_DISTRICT']::pg_catalog.text[]
      )
      AND (p_level_id IS NULL OR unit.geography_level_id = p_level_id)
      AND (p_parent_id IS NULL OR unit.parent_geography_unit_id = p_parent_id)
      AND (p_status IS NULL OR unit.status = p_status)
      AND (
          p_search IS NULL
          OR pg_catalog.upper(unit.display_name) LIKE '%' || pg_catalog.upper(p_search) || '%'
          OR pg_catalog.upper(unit.official_name) LIKE '%' || pg_catalog.upper(p_search) || '%'
          OR unit.official_code ILIKE '%' || p_search || '%'
      );

    RETURN pg_catalog.jsonb_build_object(
        'rows', COALESCE(v_rows, '[]'::pg_catalog.jsonb),
        'total', v_total
    );
END;
$function$;

ALTER FUNCTION public.rpc_get_units(
    pg_catalog.uuid,
    pg_catalog.uuid,
    pg_catalog.uuid,
    pg_catalog.text,
    pg_catalog.text,
    pg_catalog.int4,
    pg_catalog.int4
) OWNER TO postgres;

REVOKE ALL ON FUNCTION public.rpc_get_units(
    pg_catalog.uuid,
    pg_catalog.uuid,
    pg_catalog.uuid,
    pg_catalog.text,
    pg_catalog.text,
    pg_catalog.int4,
    pg_catalog.int4
) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.rpc_get_units(
    pg_catalog.uuid,
    pg_catalog.uuid,
    pg_catalog.uuid,
    pg_catalog.text,
    pg_catalog.text,
    pg_catalog.int4,
    pg_catalog.int4
) TO service_role;
