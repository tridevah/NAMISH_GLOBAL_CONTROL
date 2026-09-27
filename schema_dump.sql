


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "audit";


ALTER SCHEMA "audit" OWNER TO "postgres";


CREATE SCHEMA IF NOT EXISTS "billing";


ALTER SCHEMA "billing" OWNER TO "postgres";


CREATE SCHEMA IF NOT EXISTS "catalog";


ALTER SCHEMA "catalog" OWNER TO "postgres";


CREATE SCHEMA IF NOT EXISTS "data_imports";


ALTER SCHEMA "data_imports" OWNER TO "postgres";


CREATE SCHEMA IF NOT EXISTS "integration";


ALTER SCHEMA "integration" OWNER TO "postgres";


CREATE SCHEMA IF NOT EXISTS "platform";


ALTER SCHEMA "platform" OWNER TO "postgres";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE SCHEMA IF NOT EXISTS "staging";


ALTER SCHEMA "staging" OWNER TO "postgres";


CREATE EXTENSION IF NOT EXISTS "btree_gist" WITH SCHEMA "public";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "catalog"."rpc_mutate_tax_entity"("p_table_name" "text", "p_action" "text", "p_payload" "jsonb", "p_actor_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog'
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


ALTER FUNCTION "catalog"."rpc_mutate_tax_entity"("p_table_name" "text", "p_action" "text", "p_payload" "jsonb", "p_actor_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "catalog"."validate_block_district_relationship"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'pg_temp'
    AS $$
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
$$;


ALTER FUNCTION "catalog"."validate_block_district_relationship"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "catalog"."validate_geography_unit_parent"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog'
    AS $$
DECLARE
    v_level_number INT;
    v_parent_level_number INT;
BEGIN
    SELECT level_number INTO v_level_number FROM catalog.geography_levels WHERE id = NEW.geography_level_id;
    
    IF NEW.parent_geography_unit_id IS NULL THEN
        IF v_level_number > 1 THEN
            RAISE EXCEPTION 'Non-root geography units must have a parent';
        END IF;
    ELSE
        SELECT l.level_number INTO v_parent_level_number 
        FROM catalog.geography_units u
        JOIN catalog.geography_levels l ON l.id = u.geography_level_id
        WHERE u.id = NEW.parent_geography_unit_id;
        
        IF v_level_number != v_parent_level_number + 1 THEN
            RAISE EXCEPTION 'Parent must belong to the immediately preceding configured level';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "catalog"."validate_geography_unit_parent"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "data_imports"."trg_enforce_artifact_immutability"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'pg_temp'
    AS $$
BEGIN
    RAISE EXCEPTION 'release_execution_artifacts is append-only; % is forbidden', TG_OP;
END;
$$;


ALTER FUNCTION "data_imports"."trg_enforce_artifact_immutability"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "integration"."enqueue_webhook"("p_event_type" "text", "p_payload" "jsonb", "p_idempotency_key" "text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog'
    AS $$
DECLARE
    v_id pg_catalog.uuid;
BEGIN
    INSERT INTO integration.outbox_events (event_type, payload, idempotency_key, status, created_at)
    VALUES (p_event_type, p_payload, p_idempotency_key, 'PENDING', pg_catalog.now())
    RETURNING id INTO v_id;
    RETURN v_id;
END;
$$;


ALTER FUNCTION "integration"."enqueue_webhook"("p_event_type" "text", "p_payload" "jsonb", "p_idempotency_key" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."resolve_platform_staff_authority"("p_auth_user_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog'
    AS $$
DECLARE
    v_staff_record pg_catalog.record;
BEGIN
    SELECT id, email, role, status
    INTO v_staff_record
    FROM platform.platform_staff
    WHERE id = p_auth_user_id;

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    RETURN pg_catalog.jsonb_build_object(
        'id', v_staff_record.id,
        'email', v_staff_record.email,
        'role', v_staff_record.role,
        'status', v_staff_record.status
    );
END;
$$;


ALTER FUNCTION "public"."resolve_platform_staff_authority"("p_auth_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rls_auto_enable"() RETURNS "event_trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog'
    AS $$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$$;


ALTER FUNCTION "public"."rls_auto_enable"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "catalog"."countries" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "iso2" "text" NOT NULL,
    "iso3" "text" NOT NULL,
    "numeric_code" "text",
    "official_name" "text" NOT NULL,
    "display_name" "text" NOT NULL,
    "default_currency_code" "text" NOT NULL,
    "status" "text" DEFAULT 'ACTIVE'::"text" NOT NULL,
    "effective_from" timestamp with time zone DEFAULT "now"() NOT NULL,
    "effective_to" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "created_by" "uuid",
    "updated_by" "uuid",
    CONSTRAINT "countries_effective_dates_check" CHECK ((("effective_to" IS NULL) OR ("effective_to" >= "effective_from"))),
    CONSTRAINT "countries_status_check" CHECK (("status" = ANY (ARRAY['ACTIVE'::"text", 'INACTIVE'::"text"])))
);

ALTER TABLE ONLY "catalog"."countries" FORCE ROW LEVEL SECURITY;


ALTER TABLE "catalog"."countries" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rpc_create_country"("p_iso2" "text", "p_iso3" "text", "p_numeric_code" "text", "p_official_name" "text", "p_display_name" "text", "p_default_currency_code" "text", "p_staff_id" "uuid") RETURNS "catalog"."countries"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog'
    AS $$
DECLARE
    v_record catalog.countries;
BEGIN
    INSERT INTO catalog.countries (iso2, iso3, numeric_code, official_name, display_name, default_currency_code, created_by)
    VALUES (p_iso2, p_iso3, p_numeric_code, p_official_name, p_display_name, p_default_currency_code, p_staff_id)
    RETURNING * INTO v_record;
    RETURN v_record;
END;
$$;


ALTER FUNCTION "public"."rpc_create_country"("p_iso2" "text", "p_iso3" "text", "p_numeric_code" "text", "p_official_name" "text", "p_display_name" "text", "p_default_currency_code" "text", "p_staff_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rpc_create_level"("p_country_id" "uuid", "p_level_number" integer, "p_level_key" "text", "p_display_label" "text", "p_staff_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog'
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


ALTER FUNCTION "public"."rpc_create_level"("p_country_id" "uuid", "p_level_number" integer, "p_level_key" "text", "p_display_label" "text", "p_staff_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rpc_create_postal_code"("p_country_id" "uuid", "p_postal_code" "text", "p_staff_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog'
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


ALTER FUNCTION "public"."rpc_create_postal_code"("p_country_id" "uuid", "p_postal_code" "text", "p_staff_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rpc_create_unit"("p_country_id" "uuid", "p_geography_level_id" "uuid", "p_parent_geography_unit_id" "uuid", "p_official_code" "text", "p_iso_subdivision_code" "text", "p_official_name" "text", "p_display_name" "text", "p_staff_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog'
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


ALTER FUNCTION "public"."rpc_create_unit"("p_country_id" "uuid", "p_geography_level_id" "uuid", "p_parent_geography_unit_id" "uuid", "p_official_code" "text", "p_iso_subdivision_code" "text", "p_official_name" "text", "p_display_name" "text", "p_staff_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rpc_get_countries"() RETURNS SETOF "catalog"."countries"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog'
    AS $$
BEGIN
    RETURN QUERY SELECT * FROM catalog.countries ORDER BY display_name;
END;
$$;


ALTER FUNCTION "public"."rpc_get_countries"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rpc_get_country_currencies"("p_iso2" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'pg_catalog'
    AS $$
DECLARE
  v_result pg_catalog.jsonb;
BEGIN
  SELECT pg_catalog.jsonb_agg(
    pg_catalog.jsonb_build_object(
      'iso_alpha_code',   cu.iso_alpha_code,
      'iso_numeric_code', cu.iso_numeric_code,
      'name',             cu.name,
      'default_symbol',   cu.default_symbol,
      'native_symbol',    cu.native_symbol,
      'minor_units',      cu.minor_units,
      'status',           cu.status,
      'country_iso2',     co.iso2,
      'country_iso3',     co.iso3,
      'country_name',     co.display_name
    )
    ORDER BY co.iso2
  ) INTO v_result
  FROM catalog.countries co
  JOIN catalog.currencies cu ON cu.iso_alpha_code = co.default_currency_code
  WHERE cu.status = 'ACTIVE'
    AND (p_iso2 IS NULL OR pg_catalog.upper(co.iso2) = pg_catalog.upper(p_iso2));

  RETURN pg_catalog.coalesce(v_result, '[]'::pg_catalog.jsonb);
END;
$$;


ALTER FUNCTION "public"."rpc_get_country_currencies"("p_iso2" "text") OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "catalog"."currencies" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "iso_alpha_code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "default_symbol" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "iso_numeric_code" "text",
    "native_symbol" "text",
    "minor_units" integer DEFAULT 2,
    "status" "text" DEFAULT 'ACTIVE'::"text",
    "effective_from" timestamp with time zone DEFAULT "now"() NOT NULL,
    "effective_to" timestamp with time zone
);

ALTER TABLE ONLY "catalog"."currencies" FORCE ROW LEVEL SECURITY;


ALTER TABLE "catalog"."currencies" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rpc_get_currencies"() RETURNS SETOF "catalog"."currencies"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'pg_catalog'
    AS $$
BEGIN
  RETURN QUERY SELECT * FROM catalog.currencies WHERE status = 'ACTIVE' ORDER BY iso_alpha_code;
END;
$$;


ALTER FUNCTION "public"."rpc_get_currencies"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rpc_get_development_blocks"() RETURNS TABLE("id" "uuid", "district_ids" "uuid"[], "official_code" "text", "official_name" "text", "status" "text", "created_at" timestamp with time zone, "updated_at" timestamp with time zone, "created_by" "uuid", "updated_by" "uuid")
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'pg_temp'
    AS $$
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
$$;


ALTER FUNCTION "public"."rpc_get_development_blocks"() OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "catalog"."geography_levels" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "country_id" "uuid" NOT NULL,
    "level_number" integer NOT NULL,
    "level_key" "text" NOT NULL,
    "display_label" "text" NOT NULL,
    "status" "text" DEFAULT 'ACTIVE'::"text" NOT NULL,
    "effective_from" timestamp with time zone DEFAULT "now"() NOT NULL,
    "effective_to" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "created_by" "uuid",
    "updated_by" "uuid",
    CONSTRAINT "geography_levels_check" CHECK ((("effective_to" IS NULL) OR ("effective_to" >= "effective_from"))),
    CONSTRAINT "geography_levels_level_number_check" CHECK (("level_number" > 0)),
    CONSTRAINT "geography_levels_status_check" CHECK (("status" = ANY (ARRAY['ACTIVE'::"text", 'INACTIVE'::"text"])))
);

ALTER TABLE ONLY "catalog"."geography_levels" FORCE ROW LEVEL SECURITY;


ALTER TABLE "catalog"."geography_levels" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rpc_get_levels"("p_country_id" "uuid") RETURNS SETOF "catalog"."geography_levels"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog'
    AS $$
BEGIN
    RETURN QUERY SELECT * FROM catalog.geography_levels WHERE country_id = p_country_id ORDER BY level_number;
END;
$$;


ALTER FUNCTION "public"."rpc_get_levels"("p_country_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rpc_get_postal_codes"("p_country_id" "uuid", "p_status" "text" DEFAULT NULL::"text", "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 100, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog'
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


ALTER FUNCTION "public"."rpc_get_postal_codes"("p_country_id" "uuid", "p_status" "text", "p_search" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rpc_get_units"("p_country_id" "uuid", "p_level_id" "uuid" DEFAULT NULL::"uuid", "p_parent_id" "uuid" DEFAULT NULL::"uuid", "p_status" "text" DEFAULT NULL::"text", "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 200, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'pg_temp'
    AS $$
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
$$;


ALTER FUNCTION "public"."rpc_get_units"("p_country_id" "uuid", "p_level_id" "uuid", "p_parent_id" "uuid", "p_status" "text", "p_search" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rpc_set_postal_mappings"("p_postal_code_id" "uuid", "p_geography_unit_ids" "uuid"[], "p_staff_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog'
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


ALTER FUNCTION "public"."rpc_set_postal_mappings"("p_postal_code_id" "uuid", "p_geography_unit_ids" "uuid"[], "p_staff_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rpc_update_country"("p_id" "uuid", "p_official_name" "text", "p_display_name" "text", "p_default_currency_code" "text", "p_status" "text", "p_staff_id" "uuid") RETURNS "catalog"."countries"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog'
    AS $$
DECLARE
    v_record catalog.countries;
BEGIN
    UPDATE catalog.countries 
    SET official_name = p_official_name,
        display_name = p_display_name,
        default_currency_code = p_default_currency_code,
        status = p_status,
        updated_by = p_staff_id,
        updated_at = pg_catalog.now()
    WHERE id = p_id
    RETURNING * INTO v_record;
    RETURN v_record;
END;
$$;


ALTER FUNCTION "public"."rpc_update_country"("p_id" "uuid", "p_official_name" "text", "p_display_name" "text", "p_default_currency_code" "text", "p_status" "text", "p_staff_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rpc_update_level"("p_id" "uuid", "p_display_label" "text", "p_status" "text", "p_staff_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog'
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


ALTER FUNCTION "public"."rpc_update_level"("p_id" "uuid", "p_display_label" "text", "p_status" "text", "p_staff_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rpc_update_postal_code"("p_id" "uuid", "p_postal_code" "text", "p_status" "text", "p_staff_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog'
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


ALTER FUNCTION "public"."rpc_update_postal_code"("p_id" "uuid", "p_postal_code" "text", "p_status" "text", "p_staff_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rpc_update_unit"("p_id" "uuid", "p_official_name" "text", "p_display_name" "text", "p_iso_subdivision_code" "text", "p_status" "text", "p_staff_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog'
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


ALTER FUNCTION "public"."rpc_update_unit"("p_id" "uuid", "p_official_name" "text", "p_display_name" "text", "p_iso_subdivision_code" "text", "p_status" "text", "p_staff_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rpc_write_audit"("p_staff_id" "uuid", "p_action" "text", "p_resource" "text", "p_resource_id" "uuid", "p_payload" "jsonb") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog'
    AS $$
BEGIN
    INSERT INTO audit.staff_events(staff_id, action, resource, resource_id, payload)
    VALUES (p_staff_id, p_action, p_resource, p_resource_id, p_payload);
END;
$$;


ALTER FUNCTION "public"."rpc_write_audit"("p_staff_id" "uuid", "p_action" "text", "p_resource" "text", "p_resource_id" "uuid", "p_payload" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "staging"."trg_enforce_geography_import_identity"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'pg_temp'
    AS $$
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
$$;


ALTER FUNCTION "staging"."trg_enforce_geography_import_identity"() OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "audit"."publication_history" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "release_id" "uuid" NOT NULL,
    "staff_id" "uuid" NOT NULL,
    "published_at" timestamp with time zone DEFAULT "now"()
);

ALTER TABLE ONLY "audit"."publication_history" FORCE ROW LEVEL SECURITY;


ALTER TABLE "audit"."publication_history" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "audit"."staff_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "staff_id" "uuid" NOT NULL,
    "action" "text" NOT NULL,
    "resource" "text" NOT NULL,
    "resource_id" "uuid",
    "payload" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"()
);

ALTER TABLE ONLY "audit"."staff_events" FORCE ROW LEVEL SECURITY;


ALTER TABLE "audit"."staff_events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "billing"."entitlements" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "subscription_id" "uuid" NOT NULL,
    "feature_key" "text" NOT NULL,
    "value" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"()
);

ALTER TABLE ONLY "billing"."entitlements" FORCE ROW LEVEL SECURITY;


ALTER TABLE "billing"."entitlements" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "billing"."invoices" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "subscription_id" "uuid" NOT NULL,
    "amount" numeric NOT NULL,
    "status" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);

ALTER TABLE ONLY "billing"."invoices" FORCE ROW LEVEL SECURITY;


ALTER TABLE "billing"."invoices" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "billing"."payment_webhook_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "provider" "text" NOT NULL,
    "event_type" "text" NOT NULL,
    "payload" "jsonb" NOT NULL,
    "processed" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"()
);

ALTER TABLE ONLY "billing"."payment_webhook_events" FORCE ROW LEVEL SECURITY;


ALTER TABLE "billing"."payment_webhook_events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "billing"."plans" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "features" "jsonb",
    "price" numeric NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);

ALTER TABLE ONLY "billing"."plans" FORCE ROW LEVEL SECURITY;


ALTER TABLE "billing"."plans" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "billing"."subscriptions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "platform_account_id" "uuid" NOT NULL,
    "plan_id" "uuid" NOT NULL,
    "status" "text" NOT NULL,
    "current_period_start" timestamp with time zone,
    "current_period_end" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"()
);

ALTER TABLE ONLY "billing"."subscriptions" FORCE ROW LEVEL SECURITY;


ALTER TABLE "billing"."subscriptions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "catalog"."applicability_scopes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "country_id" "uuid" NOT NULL,
    "scope_type" "text" NOT NULL,
    "priority" integer DEFAULT 0 NOT NULL,
    "status" "text" DEFAULT 'ACTIVE'::"text" NOT NULL,
    "effective_from" timestamp with time zone DEFAULT "now"() NOT NULL,
    "effective_to" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "applicability_scopes_scope_type_check" CHECK (("scope_type" = ANY (ARRAY['COUNTRY_WIDE'::"text", 'GEOGRAPHIC'::"text"]))),
    CONSTRAINT "applicability_scopes_status_check" CHECK (("status" = ANY (ARRAY['ACTIVE'::"text", 'INACTIVE'::"text"])))
);


ALTER TABLE "catalog"."applicability_scopes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "catalog"."block_districts" (
    "block_id" "uuid" NOT NULL,
    "district_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "source_release_id" "uuid"
);

ALTER TABLE ONLY "catalog"."block_districts" FORCE ROW LEVEL SECURITY;


ALTER TABLE "catalog"."block_districts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "catalog"."catalog_release_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "release_id" "uuid" NOT NULL,
    "item_type" "text" NOT NULL,
    "item_id" "uuid" NOT NULL,
    "payload" "jsonb" NOT NULL
);

ALTER TABLE ONLY "catalog"."catalog_release_items" FORCE ROW LEVEL SECURITY;


ALTER TABLE "catalog"."catalog_release_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "catalog"."catalog_releases" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "version" "text" NOT NULL,
    "status" "text" DEFAULT 'DRAFT'::"text" NOT NULL,
    "published_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"()
);

ALTER TABLE ONLY "catalog"."catalog_releases" FORCE ROW LEVEL SECURITY;


ALTER TABLE "catalog"."catalog_releases" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "catalog"."country_currencies" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "country_id" "uuid" NOT NULL,
    "currency_id" "uuid" NOT NULL,
    "is_primary" boolean DEFAULT false NOT NULL,
    "effective_from" timestamp with time zone DEFAULT "now"() NOT NULL,
    "effective_to" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"()
);

ALTER TABLE ONLY "catalog"."country_currencies" FORCE ROW LEVEL SECURITY;


ALTER TABLE "catalog"."country_currencies" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "catalog"."country_tax_coverage" (
    "country_id" "uuid" NOT NULL,
    "status" "text" NOT NULL,
    "reason" "text",
    "official_website" "text",
    "provenance_reference" "text",
    "checked_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "country_tax_coverage_status_check" CHECK (("status" = ANY (ARRAY['VERIFIED'::"text", 'NOT_APPLICABLE'::"text", 'UNRESOLVED'::"text"])))
);

ALTER TABLE ONLY "catalog"."country_tax_coverage" FORCE ROW LEVEL SECURITY;


ALTER TABLE "catalog"."country_tax_coverage" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "catalog"."development_blocks" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "official_code" "text" NOT NULL,
    "official_name" "text" NOT NULL,
    "status" "text" DEFAULT 'ACTIVE'::"text" NOT NULL,
    "district_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_by" "uuid",
    "updated_by" "uuid",
    CONSTRAINT "development_blocks_official_code_check" CHECK (("btrim"("official_code") <> ''::"text")),
    CONSTRAINT "development_blocks_official_name_check" CHECK (("btrim"("official_name") <> ''::"text")),
    CONSTRAINT "development_blocks_status_check" CHECK (("status" = ANY (ARRAY['ACTIVE'::"text", 'INACTIVE'::"text"])))
);

ALTER TABLE ONLY "catalog"."development_blocks" FORCE ROW LEVEL SECURITY;


ALTER TABLE "catalog"."development_blocks" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "catalog"."geo_masters" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "type" "text" NOT NULL,
    "code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "parent_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"()
);

ALTER TABLE ONLY "catalog"."geo_masters" FORCE ROW LEVEL SECURITY;


ALTER TABLE "catalog"."geo_masters" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "catalog"."geography_units" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "country_id" "uuid" NOT NULL,
    "geography_level_id" "uuid" NOT NULL,
    "parent_geography_unit_id" "uuid",
    "official_code" "text" NOT NULL,
    "iso_subdivision_code" "text",
    "official_name" "text" NOT NULL,
    "display_name" "text" NOT NULL,
    "status" "text" DEFAULT 'ACTIVE'::"text" NOT NULL,
    "effective_from" timestamp with time zone DEFAULT "now"() NOT NULL,
    "effective_to" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "created_by" "uuid",
    "updated_by" "uuid",
    CONSTRAINT "geography_units_check" CHECK ((("effective_to" IS NULL) OR ("effective_to" >= "effective_from"))),
    CONSTRAINT "geography_units_status_check" CHECK (("status" = ANY (ARRAY['ACTIVE'::"text", 'INACTIVE'::"text"])))
);

ALTER TABLE ONLY "catalog"."geography_units" FORCE ROW LEVEL SECURITY;


ALTER TABLE "catalog"."geography_units" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "catalog"."hsn_sac" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "code" "text" NOT NULL,
    "description" "text",
    "type" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "hsn_sac_type_check" CHECK (("type" = ANY (ARRAY['HSN'::"text", 'SAC'::"text"])))
);

ALTER TABLE ONLY "catalog"."hsn_sac" FORCE ROW LEVEL SECURITY;


ALTER TABLE "catalog"."hsn_sac" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "catalog"."jurisdictions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "country_id" "uuid",
    "applicability_scope_id" "uuid"
);

ALTER TABLE ONLY "catalog"."jurisdictions" FORCE ROW LEVEL SECURITY;


ALTER TABLE "catalog"."jurisdictions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "catalog"."postal_code_geographies" (
    "postal_code_id" "uuid" NOT NULL,
    "geography_unit_id" "uuid" NOT NULL,
    "country_id" "uuid" NOT NULL
);

ALTER TABLE ONLY "catalog"."postal_code_geographies" FORCE ROW LEVEL SECURITY;


ALTER TABLE "catalog"."postal_code_geographies" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "catalog"."postal_codes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "country_id" "uuid" NOT NULL,
    "postal_code" "text" NOT NULL,
    "status" "text" DEFAULT 'ACTIVE'::"text" NOT NULL,
    "effective_from" timestamp with time zone DEFAULT "now"() NOT NULL,
    "effective_to" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "created_by" "uuid",
    "updated_by" "uuid",
    CONSTRAINT "postal_codes_check" CHECK ((("effective_to" IS NULL) OR ("effective_to" >= "effective_from"))),
    CONSTRAINT "postal_codes_status_check" CHECK (("status" = ANY (ARRAY['ACTIVE'::"text", 'INACTIVE'::"text"])))
);

ALTER TABLE ONLY "catalog"."postal_codes" FORCE ROW LEVEL SECURITY;


ALTER TABLE "catalog"."postal_codes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "catalog"."tax_authorities" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "country_id" "uuid" NOT NULL,
    "jurisdiction_id" "uuid" NOT NULL,
    "tax_type" "text" NOT NULL,
    "authority_name" "text" NOT NULL,
    "official_website" "text",
    "provenance_reference" "text",
    "status" "text" DEFAULT 'ACTIVE'::"text" NOT NULL,
    "effective_from" timestamp with time zone DEFAULT "now"() NOT NULL,
    "effective_to" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "tax_authorities_status_check" CHECK (("status" = ANY (ARRAY['ACTIVE'::"text", 'INACTIVE'::"text"]))),
    CONSTRAINT "tax_authorities_tax_type_check" CHECK (("tax_type" = ANY (ARRAY['GST'::"text", 'VAT'::"text", 'SALES_TAX'::"text", 'WITHHOLDING'::"text", 'TDS'::"text", 'CUSTOMS'::"text", 'EXCISE'::"text"])))
);

ALTER TABLE ONLY "catalog"."tax_authorities" FORCE ROW LEVEL SECURITY;


ALTER TABLE "catalog"."tax_authorities" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "catalog"."tax_codes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "jurisdiction_id" "uuid" NOT NULL,
    "code" "text" NOT NULL,
    "description" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);

ALTER TABLE ONLY "catalog"."tax_codes" FORCE ROW LEVEL SECURITY;


ALTER TABLE "catalog"."tax_codes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "catalog"."tax_rates" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tax_code_id" "uuid" NOT NULL,
    "rate" numeric NOT NULL,
    "effective_from" timestamp with time zone NOT NULL,
    "effective_to" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"()
);

ALTER TABLE ONLY "catalog"."tax_rates" FORCE ROW LEVEL SECURITY;


ALTER TABLE "catalog"."tax_rates" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "catalog"."uqc" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "code" "text" NOT NULL,
    "description" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);

ALTER TABLE ONLY "catalog"."uqc" FORCE ROW LEVEL SECURITY;


ALTER TABLE "catalog"."uqc" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "data_imports"."batches" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "release_id" "uuid" NOT NULL,
    "logical_batch_key" "text" NOT NULL,
    "entity_type" "text" NOT NULL,
    "total_records" integer DEFAULT 0 NOT NULL,
    "successful_records" integer DEFAULT 0 NOT NULL,
    "failed_records" integer DEFAULT 0 NOT NULL,
    "status" "text" DEFAULT 'PENDING'::"text" NOT NULL,
    "started_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "completed_at" timestamp with time zone,
    CONSTRAINT "batches_entity_type_check" CHECK (("entity_type" = ANY (ARRAY['STATE'::"text", 'DISTRICT'::"text", 'SUB_DISTRICT'::"text", 'BLOCK'::"text"]))),
    CONSTRAINT "batches_failed_records_check" CHECK (("failed_records" >= 0)),
    CONSTRAINT "batches_logical_batch_key_check" CHECK (("btrim"("logical_batch_key") <> ''::"text")),
    CONSTRAINT "batches_status_check" CHECK (("status" = ANY (ARRAY['PENDING'::"text", 'EXTRACTING'::"text", 'STAGED'::"text", 'OFFICIAL_EMPTY'::"text", 'PROMOTED'::"text", 'FINALIZED'::"text", 'FAILED'::"text"]))),
    CONSTRAINT "batches_successful_records_check" CHECK (("successful_records" >= 0)),
    CONSTRAINT "batches_total_records_check" CHECK (("total_records" >= 0))
);

ALTER TABLE ONLY "data_imports"."batches" FORCE ROW LEVEL SECURITY;


ALTER TABLE "data_imports"."batches" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "data_imports"."release_execution_artifacts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "release_id" "uuid" NOT NULL,
    "artifact_type" "text" NOT NULL,
    "artifact_payload" "jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "release_execution_artifacts_artifact_type_check" CHECK (("btrim"("artifact_type") <> ''::"text"))
);

ALTER TABLE ONLY "data_imports"."release_execution_artifacts" FORCE ROW LEVEL SECURITY;


ALTER TABLE "data_imports"."release_execution_artifacts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "data_imports"."releases" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "release_name" "text" NOT NULL,
    "source_uri" "text" NOT NULL,
    "sha256_hash" "text" NOT NULL,
    "manifest_hash" "text" NOT NULL,
    "status" "text" DEFAULT 'PENDING'::"text" NOT NULL,
    "started_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "completed_at" timestamp with time zone,
    CONSTRAINT "releases_manifest_hash_check" CHECK (("manifest_hash" ~ '^[0-9A-Fa-f]{64}$'::"text")),
    CONSTRAINT "releases_release_name_check" CHECK (("btrim"("release_name") <> ''::"text")),
    CONSTRAINT "releases_sha256_hash_check" CHECK (("sha256_hash" ~ '^[0-9A-Fa-f]{64}$'::"text")),
    CONSTRAINT "releases_source_uri_check" CHECK (("btrim"("source_uri") <> ''::"text")),
    CONSTRAINT "releases_status_check" CHECK (("status" = ANY (ARRAY['PENDING'::"text", 'STAGED'::"text", 'PROMOTED'::"text", 'FINALIZED'::"text", 'INVALIDATED'::"text", 'FAILED'::"text"])))
);

ALTER TABLE ONLY "data_imports"."releases" FORCE ROW LEVEL SECURITY;


ALTER TABLE "data_imports"."releases" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "data_imports"."row_errors" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "batch_id" "uuid" NOT NULL,
    "official_code" "text",
    "row_data" "jsonb" NOT NULL,
    "error_message" "text" NOT NULL,
    "occurrence_count" bigint DEFAULT 1 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "row_errors_occurrence_count_check" CHECK (("occurrence_count" > 0))
);

ALTER TABLE ONLY "data_imports"."row_errors" FORCE ROW LEVEL SECURITY;


ALTER TABLE "data_imports"."row_errors" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "integration"."delivery_attempts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "event_id" "uuid" NOT NULL,
    "endpoint_id" "uuid" NOT NULL,
    "status" "text" NOT NULL,
    "response_code" integer,
    "response_body" "text",
    "attempted_at" timestamp with time zone DEFAULT "now"()
);

ALTER TABLE ONLY "integration"."delivery_attempts" FORCE ROW LEVEL SECURITY;


ALTER TABLE "integration"."delivery_attempts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "integration"."idempotency_records" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "key" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);

ALTER TABLE ONLY "integration"."idempotency_records" FORCE ROW LEVEL SECURITY;


ALTER TABLE "integration"."idempotency_records" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "integration"."outbox_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "event_type" "text" NOT NULL,
    "payload" "jsonb" NOT NULL,
    "idempotency_key" "text" NOT NULL,
    "status" "text" DEFAULT 'PENDING'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);

ALTER TABLE ONLY "integration"."outbox_events" FORCE ROW LEVEL SECURITY;


ALTER TABLE "integration"."outbox_events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "integration"."webhook_endpoints" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "url" "text" NOT NULL,
    "secret" "text" NOT NULL,
    "description" "text",
    "status" "text" DEFAULT 'ACTIVE'::"text",
    "created_at" timestamp with time zone DEFAULT "now"()
);

ALTER TABLE ONLY "integration"."webhook_endpoints" FORCE ROW LEVEL SECURITY;


ALTER TABLE "integration"."webhook_endpoints" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "platform"."account_owners" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "platform_account_id" "uuid" NOT NULL,
    "email" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);

ALTER TABLE ONLY "platform"."account_owners" FORCE ROW LEVEL SECURITY;


ALTER TABLE "platform"."account_owners" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "platform"."platform_accounts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "status" "text" DEFAULT 'ACTIVE'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);

ALTER TABLE ONLY "platform"."platform_accounts" FORCE ROW LEVEL SECURITY;


ALTER TABLE "platform"."platform_accounts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "platform"."platform_staff" (
    "id" "uuid" NOT NULL,
    "email" "text" NOT NULL,
    "role" "text" NOT NULL,
    "status" "text" DEFAULT 'ACTIVE'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "platform_staff_role_check" CHECK (("role" = ANY (ARRAY['PLATFORM_SUPERADMIN'::"text", 'CATALOG_MANAGER'::"text", 'BILLING_MANAGER'::"text", 'SUPPORT_AUDITOR'::"text"])))
);

ALTER TABLE ONLY "platform"."platform_staff" FORCE ROW LEVEL SECURITY;


ALTER TABLE "platform"."platform_staff" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "platform"."provisioning_jobs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tenant_id" "uuid",
    "status" "text" NOT NULL,
    "logs" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"()
);

ALTER TABLE ONLY "platform"."provisioning_jobs" FORCE ROW LEVEL SECURITY;


ALTER TABLE "platform"."provisioning_jobs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "platform"."tenant_registry" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "platform_account_id" "uuid" NOT NULL,
    "erp_tenant_id" "uuid",
    "status" "text" DEFAULT 'PROVISIONING'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);

ALTER TABLE ONLY "platform"."tenant_registry" FORCE ROW LEVEL SECURITY;


ALTER TABLE "platform"."tenant_registry" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "staging"."geography_imports" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "batch_id" "uuid" NOT NULL,
    "release_id" "uuid" NOT NULL,
    "entity_type" "text" NOT NULL,
    "entity_code" "text",
    "parent_code" "text",
    "entity_name" "text",
    "raw_data" "jsonb" NOT NULL,
    "validation_status" "text" DEFAULT 'PENDING'::"text" NOT NULL,
    "error_message" "text",
    "physical_row_number" integer NOT NULL,
    "chunk_hash" "text",
    "classification" "text" DEFAULT 'PENDING'::"text" NOT NULL,
    "observation_identity_version" "text" NOT NULL,
    "source_observation_key" "text" NOT NULL,
    "physical_source_sha256" "text" NOT NULL,
    "internal_member_or_sheet" "text" NOT NULL,
    "logical_output_ordinal" integer NOT NULL,
    "emitted_record_ordinal" integer NOT NULL,
    "raw_payload_sha256" "text" NOT NULL,
    "canonical_identity_key" "text",
    "observation_classification" "text",
    "importer_replay_count" bigint DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "geography_imports_emitted_record_ordinal_check" CHECK (("emitted_record_ordinal" > 0)),
    CONSTRAINT "geography_imports_entity_type_check" CHECK (("entity_type" = ANY (ARRAY['STATE'::"text", 'DISTRICT'::"text", 'SUB_DISTRICT'::"text", 'BLOCK'::"text"]))),
    CONSTRAINT "geography_imports_importer_replay_count_check" CHECK (("importer_replay_count" >= 0)),
    CONSTRAINT "geography_imports_internal_member_or_sheet_check" CHECK (("btrim"("internal_member_or_sheet") <> ''::"text")),
    CONSTRAINT "geography_imports_logical_output_ordinal_check" CHECK (("logical_output_ordinal" >= 0)),
    CONSTRAINT "geography_imports_observation_identity_version_check" CHECK (("btrim"("observation_identity_version") <> ''::"text")),
    CONSTRAINT "geography_imports_physical_row_number_check" CHECK (("physical_row_number" > 0)),
    CONSTRAINT "geography_imports_physical_source_sha256_check" CHECK (("btrim"("physical_source_sha256") <> ''::"text")),
    CONSTRAINT "geography_imports_raw_payload_sha256_check" CHECK (("raw_payload_sha256" ~ '^[0-9A-Fa-f]{64}$'::"text")),
    CONSTRAINT "geography_imports_source_observation_key_check" CHECK (("btrim"("source_observation_key") <> ''::"text"))
);

ALTER TABLE ONLY "staging"."geography_imports" FORCE ROW LEVEL SECURITY;


ALTER TABLE "staging"."geography_imports" OWNER TO "postgres";


ALTER TABLE ONLY "audit"."publication_history"
    ADD CONSTRAINT "publication_history_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "audit"."staff_events"
    ADD CONSTRAINT "staff_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "billing"."entitlements"
    ADD CONSTRAINT "entitlements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "billing"."invoices"
    ADD CONSTRAINT "invoices_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "billing"."payment_webhook_events"
    ADD CONSTRAINT "payment_webhook_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "billing"."plans"
    ADD CONSTRAINT "plans_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "billing"."subscriptions"
    ADD CONSTRAINT "subscriptions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "catalog"."applicability_scopes"
    ADD CONSTRAINT "applicability_scopes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "catalog"."block_districts"
    ADD CONSTRAINT "block_districts_pkey" PRIMARY KEY ("block_id", "district_id");



ALTER TABLE ONLY "catalog"."catalog_release_items"
    ADD CONSTRAINT "catalog_release_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "catalog"."catalog_releases"
    ADD CONSTRAINT "catalog_releases_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "catalog"."catalog_releases"
    ADD CONSTRAINT "catalog_releases_version_key" UNIQUE ("version");



ALTER TABLE ONLY "catalog"."countries"
    ADD CONSTRAINT "countries_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "catalog"."country_currencies"
    ADD CONSTRAINT "country_currencies_country_id_currency_id_key" UNIQUE ("country_id", "currency_id");



ALTER TABLE ONLY "catalog"."country_currencies"
    ADD CONSTRAINT "country_currencies_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "catalog"."country_tax_coverage"
    ADD CONSTRAINT "country_tax_coverage_pkey" PRIMARY KEY ("country_id");



ALTER TABLE ONLY "catalog"."currencies"
    ADD CONSTRAINT "currencies_code_key" UNIQUE ("iso_alpha_code");



ALTER TABLE ONLY "catalog"."currencies"
    ADD CONSTRAINT "currencies_iso_alpha_code_key" UNIQUE ("iso_alpha_code");



ALTER TABLE ONLY "catalog"."currencies"
    ADD CONSTRAINT "currencies_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "catalog"."development_blocks"
    ADD CONSTRAINT "development_blocks_official_code_key" UNIQUE ("official_code");



ALTER TABLE ONLY "catalog"."development_blocks"
    ADD CONSTRAINT "development_blocks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "catalog"."geo_masters"
    ADD CONSTRAINT "geo_masters_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "catalog"."geography_levels"
    ADD CONSTRAINT "geography_levels_country_id_level_key_key" UNIQUE ("country_id", "level_key");



ALTER TABLE ONLY "catalog"."geography_levels"
    ADD CONSTRAINT "geography_levels_country_id_level_number_key" UNIQUE ("country_id", "level_number");



ALTER TABLE ONLY "catalog"."geography_levels"
    ADD CONSTRAINT "geography_levels_id_country_id_key" UNIQUE ("id", "country_id");



ALTER TABLE ONLY "catalog"."geography_levels"
    ADD CONSTRAINT "geography_levels_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "catalog"."geography_units"
    ADD CONSTRAINT "geography_units_country_id_geography_level_id_official_code_key" UNIQUE ("country_id", "geography_level_id", "official_code");



ALTER TABLE ONLY "catalog"."geography_units"
    ADD CONSTRAINT "geography_units_country_id_iso_subdivision_code_key" UNIQUE ("country_id", "iso_subdivision_code");



ALTER TABLE ONLY "catalog"."geography_units"
    ADD CONSTRAINT "geography_units_id_country_id_key" UNIQUE ("id", "country_id");



ALTER TABLE ONLY "catalog"."geography_units"
    ADD CONSTRAINT "geography_units_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "catalog"."hsn_sac"
    ADD CONSTRAINT "hsn_sac_code_key" UNIQUE ("code");



ALTER TABLE ONLY "catalog"."hsn_sac"
    ADD CONSTRAINT "hsn_sac_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "catalog"."jurisdictions"
    ADD CONSTRAINT "jurisdictions_code_key" UNIQUE ("code");



ALTER TABLE ONLY "catalog"."jurisdictions"
    ADD CONSTRAINT "jurisdictions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "catalog"."postal_code_geographies"
    ADD CONSTRAINT "postal_code_geographies_pkey" PRIMARY KEY ("postal_code_id", "geography_unit_id");



ALTER TABLE ONLY "catalog"."postal_codes"
    ADD CONSTRAINT "postal_codes_country_id_postal_code_key" UNIQUE ("country_id", "postal_code");



ALTER TABLE ONLY "catalog"."postal_codes"
    ADD CONSTRAINT "postal_codes_id_country_id_key" UNIQUE ("id", "country_id");



ALTER TABLE ONLY "catalog"."postal_codes"
    ADD CONSTRAINT "postal_codes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "catalog"."tax_authorities"
    ADD CONSTRAINT "tax_authorities_country_id_jurisdiction_id_tax_type_tstzra_excl" EXCLUDE USING "gist" ("country_id" WITH =, "jurisdiction_id" WITH =, "tax_type" WITH =, "tstzrange"("effective_from", COALESCE("effective_to", 'infinity'::timestamp with time zone), '[]'::"text") WITH &&);



ALTER TABLE ONLY "catalog"."tax_authorities"
    ADD CONSTRAINT "tax_authorities_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "catalog"."tax_codes"
    ADD CONSTRAINT "tax_codes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "catalog"."tax_rates"
    ADD CONSTRAINT "tax_rates_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "catalog"."uqc"
    ADD CONSTRAINT "uqc_code_key" UNIQUE ("code");



ALTER TABLE ONLY "catalog"."uqc"
    ADD CONSTRAINT "uqc_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "data_imports"."batches"
    ADD CONSTRAINT "batches_id_release_id_entity_type_key" UNIQUE ("id", "release_id", "entity_type");



ALTER TABLE ONLY "data_imports"."batches"
    ADD CONSTRAINT "batches_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "data_imports"."batches"
    ADD CONSTRAINT "batches_release_id_logical_batch_key_key" UNIQUE ("release_id", "logical_batch_key");



ALTER TABLE ONLY "data_imports"."release_execution_artifacts"
    ADD CONSTRAINT "release_execution_artifacts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "data_imports"."releases"
    ADD CONSTRAINT "releases_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "data_imports"."releases"
    ADD CONSTRAINT "releases_release_name_key" UNIQUE ("release_name");



ALTER TABLE ONLY "data_imports"."row_errors"
    ADD CONSTRAINT "row_errors_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "integration"."delivery_attempts"
    ADD CONSTRAINT "delivery_attempts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "integration"."idempotency_records"
    ADD CONSTRAINT "idempotency_records_key_key" UNIQUE ("key");



ALTER TABLE ONLY "integration"."idempotency_records"
    ADD CONSTRAINT "idempotency_records_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "integration"."outbox_events"
    ADD CONSTRAINT "outbox_events_idempotency_key_key" UNIQUE ("idempotency_key");



ALTER TABLE ONLY "integration"."outbox_events"
    ADD CONSTRAINT "outbox_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "integration"."webhook_endpoints"
    ADD CONSTRAINT "webhook_endpoints_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "platform"."account_owners"
    ADD CONSTRAINT "account_owners_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "platform"."platform_accounts"
    ADD CONSTRAINT "platform_accounts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "platform"."platform_staff"
    ADD CONSTRAINT "platform_staff_email_key" UNIQUE ("email");



ALTER TABLE ONLY "platform"."platform_staff"
    ADD CONSTRAINT "platform_staff_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "platform"."provisioning_jobs"
    ADD CONSTRAINT "provisioning_jobs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "platform"."tenant_registry"
    ADD CONSTRAINT "tenant_registry_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "staging"."geography_imports"
    ADD CONSTRAINT "geography_imports_pkey" PRIMARY KEY ("id");



CREATE INDEX "block_districts_district_id_idx" ON "catalog"."block_districts" USING "btree" ("district_id");



CREATE UNIQUE INDEX "countries_iso2_idx" ON "catalog"."countries" USING "btree" ("upper"("iso2"));



CREATE UNIQUE INDEX "countries_iso3_idx" ON "catalog"."countries" USING "btree" ("upper"("iso3"));



CREATE UNIQUE INDEX "geo_units_normalized_name_idx" ON "catalog"."geography_units" USING "btree" ("country_id", "geography_level_id", COALESCE("parent_geography_unit_id", '00000000-0000-0000-0000-000000000000'::"uuid"), "upper"("official_name"));



CREATE UNIQUE INDEX "geography_imports_observation_identity_idx" ON "staging"."geography_imports" USING "btree" ("release_id", "batch_id", "source_observation_key");



CREATE OR REPLACE TRIGGER "trg_validate_block_district" BEFORE INSERT OR UPDATE ON "catalog"."block_districts" FOR EACH ROW EXECUTE FUNCTION "catalog"."validate_block_district_relationship"();



CREATE OR REPLACE TRIGGER "validate_geography_unit_parent_trigger" BEFORE INSERT OR UPDATE ON "catalog"."geography_units" FOR EACH ROW EXECUTE FUNCTION "catalog"."validate_geography_unit_parent"();



CREATE OR REPLACE TRIGGER "enforce_release_execution_artifacts_immutable_rows" BEFORE DELETE OR UPDATE ON "data_imports"."release_execution_artifacts" FOR EACH ROW EXECUTE FUNCTION "data_imports"."trg_enforce_artifact_immutability"();



CREATE OR REPLACE TRIGGER "enforce_release_execution_artifacts_immutable_truncate" BEFORE TRUNCATE ON "data_imports"."release_execution_artifacts" FOR EACH STATEMENT EXECUTE FUNCTION "data_imports"."trg_enforce_artifact_immutability"();



CREATE OR REPLACE TRIGGER "trg_geography_imports_identity" BEFORE INSERT OR UPDATE ON "staging"."geography_imports" FOR EACH ROW EXECUTE FUNCTION "staging"."trg_enforce_geography_import_identity"();



ALTER TABLE ONLY "audit"."publication_history"
    ADD CONSTRAINT "publication_history_release_id_fkey" FOREIGN KEY ("release_id") REFERENCES "catalog"."catalog_releases"("id");



ALTER TABLE ONLY "audit"."publication_history"
    ADD CONSTRAINT "publication_history_staff_id_fkey" FOREIGN KEY ("staff_id") REFERENCES "platform"."platform_staff"("id");



ALTER TABLE ONLY "audit"."staff_events"
    ADD CONSTRAINT "staff_events_staff_id_fkey" FOREIGN KEY ("staff_id") REFERENCES "platform"."platform_staff"("id");



ALTER TABLE ONLY "billing"."entitlements"
    ADD CONSTRAINT "entitlements_subscription_id_fkey" FOREIGN KEY ("subscription_id") REFERENCES "billing"."subscriptions"("id");



ALTER TABLE ONLY "billing"."invoices"
    ADD CONSTRAINT "invoices_subscription_id_fkey" FOREIGN KEY ("subscription_id") REFERENCES "billing"."subscriptions"("id");



ALTER TABLE ONLY "billing"."subscriptions"
    ADD CONSTRAINT "subscriptions_plan_id_fkey" FOREIGN KEY ("plan_id") REFERENCES "billing"."plans"("id");



ALTER TABLE ONLY "billing"."subscriptions"
    ADD CONSTRAINT "subscriptions_platform_account_id_fkey" FOREIGN KEY ("platform_account_id") REFERENCES "platform"."platform_accounts"("id");



ALTER TABLE ONLY "catalog"."applicability_scopes"
    ADD CONSTRAINT "applicability_scopes_country_id_fkey" FOREIGN KEY ("country_id") REFERENCES "catalog"."countries"("id");



ALTER TABLE ONLY "catalog"."block_districts"
    ADD CONSTRAINT "block_districts_block_id_fkey" FOREIGN KEY ("block_id") REFERENCES "catalog"."development_blocks"("id");



ALTER TABLE ONLY "catalog"."block_districts"
    ADD CONSTRAINT "block_districts_district_id_fkey" FOREIGN KEY ("district_id") REFERENCES "catalog"."geography_units"("id");



ALTER TABLE ONLY "catalog"."block_districts"
    ADD CONSTRAINT "block_districts_source_release_id_fkey" FOREIGN KEY ("source_release_id") REFERENCES "data_imports"."releases"("id");



ALTER TABLE ONLY "catalog"."catalog_release_items"
    ADD CONSTRAINT "catalog_release_items_release_id_fkey" FOREIGN KEY ("release_id") REFERENCES "catalog"."catalog_releases"("id");



ALTER TABLE ONLY "catalog"."countries"
    ADD CONSTRAINT "countries_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "platform"."platform_staff"("id");



ALTER TABLE ONLY "catalog"."countries"
    ADD CONSTRAINT "countries_updated_by_fkey" FOREIGN KEY ("updated_by") REFERENCES "platform"."platform_staff"("id");



ALTER TABLE ONLY "catalog"."country_currencies"
    ADD CONSTRAINT "country_currencies_country_id_fkey" FOREIGN KEY ("country_id") REFERENCES "catalog"."countries"("id");



ALTER TABLE ONLY "catalog"."country_currencies"
    ADD CONSTRAINT "country_currencies_currency_id_fkey" FOREIGN KEY ("currency_id") REFERENCES "catalog"."currencies"("id");



ALTER TABLE ONLY "catalog"."country_tax_coverage"
    ADD CONSTRAINT "country_tax_coverage_country_id_fkey" FOREIGN KEY ("country_id") REFERENCES "catalog"."countries"("id");



ALTER TABLE ONLY "catalog"."development_blocks"
    ADD CONSTRAINT "development_blocks_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "platform"."platform_staff"("id");



ALTER TABLE ONLY "catalog"."development_blocks"
    ADD CONSTRAINT "development_blocks_district_id_fkey" FOREIGN KEY ("district_id") REFERENCES "catalog"."geography_units"("id");



ALTER TABLE ONLY "catalog"."development_blocks"
    ADD CONSTRAINT "development_blocks_updated_by_fkey" FOREIGN KEY ("updated_by") REFERENCES "platform"."platform_staff"("id");



ALTER TABLE ONLY "catalog"."geo_masters"
    ADD CONSTRAINT "geo_masters_parent_id_fkey" FOREIGN KEY ("parent_id") REFERENCES "catalog"."geo_masters"("id");



ALTER TABLE ONLY "catalog"."geography_levels"
    ADD CONSTRAINT "geography_levels_country_id_fkey" FOREIGN KEY ("country_id") REFERENCES "catalog"."countries"("id");



ALTER TABLE ONLY "catalog"."geography_levels"
    ADD CONSTRAINT "geography_levels_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "platform"."platform_staff"("id");



ALTER TABLE ONLY "catalog"."geography_levels"
    ADD CONSTRAINT "geography_levels_updated_by_fkey" FOREIGN KEY ("updated_by") REFERENCES "platform"."platform_staff"("id");



ALTER TABLE ONLY "catalog"."geography_units"
    ADD CONSTRAINT "geography_units_country_id_fkey" FOREIGN KEY ("country_id") REFERENCES "catalog"."countries"("id");



ALTER TABLE ONLY "catalog"."geography_units"
    ADD CONSTRAINT "geography_units_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "platform"."platform_staff"("id");



ALTER TABLE ONLY "catalog"."geography_units"
    ADD CONSTRAINT "geography_units_geography_level_id_country_id_fkey" FOREIGN KEY ("geography_level_id", "country_id") REFERENCES "catalog"."geography_levels"("id", "country_id");



ALTER TABLE ONLY "catalog"."geography_units"
    ADD CONSTRAINT "geography_units_parent_geography_unit_id_country_id_fkey" FOREIGN KEY ("parent_geography_unit_id", "country_id") REFERENCES "catalog"."geography_units"("id", "country_id");



ALTER TABLE ONLY "catalog"."geography_units"
    ADD CONSTRAINT "geography_units_updated_by_fkey" FOREIGN KEY ("updated_by") REFERENCES "platform"."platform_staff"("id");



ALTER TABLE ONLY "catalog"."jurisdictions"
    ADD CONSTRAINT "jurisdictions_applicability_scope_id_fkey" FOREIGN KEY ("applicability_scope_id") REFERENCES "catalog"."applicability_scopes"("id");



ALTER TABLE ONLY "catalog"."jurisdictions"
    ADD CONSTRAINT "jurisdictions_country_id_fkey" FOREIGN KEY ("country_id") REFERENCES "catalog"."countries"("id");



ALTER TABLE ONLY "catalog"."postal_code_geographies"
    ADD CONSTRAINT "postal_code_geographies_geography_unit_id_country_id_fkey" FOREIGN KEY ("geography_unit_id", "country_id") REFERENCES "catalog"."geography_units"("id", "country_id");



ALTER TABLE ONLY "catalog"."postal_code_geographies"
    ADD CONSTRAINT "postal_code_geographies_postal_code_id_country_id_fkey" FOREIGN KEY ("postal_code_id", "country_id") REFERENCES "catalog"."postal_codes"("id", "country_id");



ALTER TABLE ONLY "catalog"."postal_codes"
    ADD CONSTRAINT "postal_codes_country_id_fkey" FOREIGN KEY ("country_id") REFERENCES "catalog"."countries"("id");



ALTER TABLE ONLY "catalog"."postal_codes"
    ADD CONSTRAINT "postal_codes_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "platform"."platform_staff"("id");



ALTER TABLE ONLY "catalog"."postal_codes"
    ADD CONSTRAINT "postal_codes_updated_by_fkey" FOREIGN KEY ("updated_by") REFERENCES "platform"."platform_staff"("id");



ALTER TABLE ONLY "catalog"."tax_authorities"
    ADD CONSTRAINT "tax_authorities_country_id_fkey" FOREIGN KEY ("country_id") REFERENCES "catalog"."countries"("id");



ALTER TABLE ONLY "catalog"."tax_authorities"
    ADD CONSTRAINT "tax_authorities_jurisdiction_id_fkey" FOREIGN KEY ("jurisdiction_id") REFERENCES "catalog"."jurisdictions"("id");



ALTER TABLE ONLY "catalog"."tax_codes"
    ADD CONSTRAINT "tax_codes_jurisdiction_id_fkey" FOREIGN KEY ("jurisdiction_id") REFERENCES "catalog"."jurisdictions"("id");



ALTER TABLE ONLY "catalog"."tax_rates"
    ADD CONSTRAINT "tax_rates_tax_code_id_fkey" FOREIGN KEY ("tax_code_id") REFERENCES "catalog"."tax_codes"("id");



ALTER TABLE ONLY "data_imports"."batches"
    ADD CONSTRAINT "batches_release_id_fkey" FOREIGN KEY ("release_id") REFERENCES "data_imports"."releases"("id");



ALTER TABLE ONLY "data_imports"."release_execution_artifacts"
    ADD CONSTRAINT "release_execution_artifacts_release_id_fkey" FOREIGN KEY ("release_id") REFERENCES "data_imports"."releases"("id");



ALTER TABLE ONLY "data_imports"."row_errors"
    ADD CONSTRAINT "row_errors_batch_id_fkey" FOREIGN KEY ("batch_id") REFERENCES "data_imports"."batches"("id");



ALTER TABLE ONLY "integration"."delivery_attempts"
    ADD CONSTRAINT "delivery_attempts_endpoint_id_fkey" FOREIGN KEY ("endpoint_id") REFERENCES "integration"."webhook_endpoints"("id");



ALTER TABLE ONLY "integration"."delivery_attempts"
    ADD CONSTRAINT "delivery_attempts_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "integration"."outbox_events"("id");



ALTER TABLE ONLY "platform"."account_owners"
    ADD CONSTRAINT "account_owners_platform_account_id_fkey" FOREIGN KEY ("platform_account_id") REFERENCES "platform"."platform_accounts"("id");



ALTER TABLE ONLY "platform"."platform_staff"
    ADD CONSTRAINT "platform_staff_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "platform"."provisioning_jobs"
    ADD CONSTRAINT "provisioning_jobs_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "platform"."tenant_registry"("id");



ALTER TABLE ONLY "platform"."tenant_registry"
    ADD CONSTRAINT "tenant_registry_platform_account_id_fkey" FOREIGN KEY ("platform_account_id") REFERENCES "platform"."platform_accounts"("id");



ALTER TABLE ONLY "staging"."geography_imports"
    ADD CONSTRAINT "geography_imports_batch_id_release_id_entity_type_fkey" FOREIGN KEY ("batch_id", "release_id", "entity_type") REFERENCES "data_imports"."batches"("id", "release_id", "entity_type");



ALTER TABLE "audit"."publication_history" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "audit"."staff_events" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "billing"."entitlements" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "billing"."invoices" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "billing"."payment_webhook_events" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "billing"."plans" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "billing"."subscriptions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "catalog"."block_districts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "catalog"."catalog_release_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "catalog"."catalog_releases" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "catalog"."countries" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "catalog"."country_currencies" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "catalog"."country_tax_coverage" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "catalog"."currencies" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "catalog"."development_blocks" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "catalog"."geo_masters" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "catalog"."geography_levels" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "catalog"."geography_units" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "catalog"."hsn_sac" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "catalog"."jurisdictions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "catalog"."postal_code_geographies" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "catalog"."postal_codes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "catalog"."tax_authorities" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "catalog"."tax_codes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "catalog"."tax_rates" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "catalog"."uqc" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "data_imports"."batches" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "data_imports"."release_execution_artifacts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "data_imports"."releases" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "data_imports"."row_errors" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "integration"."delivery_attempts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "integration"."idempotency_records" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "integration"."outbox_events" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "integration"."webhook_endpoints" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "platform"."account_owners" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "platform"."platform_accounts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "platform"."platform_staff" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "platform"."provisioning_jobs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "platform"."tenant_registry" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "staging"."geography_imports" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


GRANT USAGE ON SCHEMA "audit" TO "service_role";



GRANT USAGE ON SCHEMA "billing" TO "service_role";



GRANT USAGE ON SCHEMA "catalog" TO "service_role";



GRANT USAGE ON SCHEMA "data_imports" TO "service_role";



GRANT USAGE ON SCHEMA "integration" TO "service_role";



GRANT USAGE ON SCHEMA "platform" TO "service_role";



GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



GRANT USAGE ON SCHEMA "staging" TO "service_role";



GRANT ALL ON FUNCTION "public"."gbtreekey16_in"("cstring") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbtreekey16_in"("cstring") TO "anon";
GRANT ALL ON FUNCTION "public"."gbtreekey16_in"("cstring") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbtreekey16_in"("cstring") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbtreekey16_out"("public"."gbtreekey16") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbtreekey16_out"("public"."gbtreekey16") TO "anon";
GRANT ALL ON FUNCTION "public"."gbtreekey16_out"("public"."gbtreekey16") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbtreekey16_out"("public"."gbtreekey16") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbtreekey2_in"("cstring") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbtreekey2_in"("cstring") TO "anon";
GRANT ALL ON FUNCTION "public"."gbtreekey2_in"("cstring") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbtreekey2_in"("cstring") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbtreekey2_out"("public"."gbtreekey2") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbtreekey2_out"("public"."gbtreekey2") TO "anon";
GRANT ALL ON FUNCTION "public"."gbtreekey2_out"("public"."gbtreekey2") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbtreekey2_out"("public"."gbtreekey2") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbtreekey32_in"("cstring") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbtreekey32_in"("cstring") TO "anon";
GRANT ALL ON FUNCTION "public"."gbtreekey32_in"("cstring") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbtreekey32_in"("cstring") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbtreekey32_out"("public"."gbtreekey32") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbtreekey32_out"("public"."gbtreekey32") TO "anon";
GRANT ALL ON FUNCTION "public"."gbtreekey32_out"("public"."gbtreekey32") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbtreekey32_out"("public"."gbtreekey32") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbtreekey4_in"("cstring") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbtreekey4_in"("cstring") TO "anon";
GRANT ALL ON FUNCTION "public"."gbtreekey4_in"("cstring") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbtreekey4_in"("cstring") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbtreekey4_out"("public"."gbtreekey4") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbtreekey4_out"("public"."gbtreekey4") TO "anon";
GRANT ALL ON FUNCTION "public"."gbtreekey4_out"("public"."gbtreekey4") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbtreekey4_out"("public"."gbtreekey4") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbtreekey8_in"("cstring") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbtreekey8_in"("cstring") TO "anon";
GRANT ALL ON FUNCTION "public"."gbtreekey8_in"("cstring") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbtreekey8_in"("cstring") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbtreekey8_out"("public"."gbtreekey8") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbtreekey8_out"("public"."gbtreekey8") TO "anon";
GRANT ALL ON FUNCTION "public"."gbtreekey8_out"("public"."gbtreekey8") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbtreekey8_out"("public"."gbtreekey8") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbtreekey_var_in"("cstring") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbtreekey_var_in"("cstring") TO "anon";
GRANT ALL ON FUNCTION "public"."gbtreekey_var_in"("cstring") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbtreekey_var_in"("cstring") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbtreekey_var_out"("public"."gbtreekey_var") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbtreekey_var_out"("public"."gbtreekey_var") TO "anon";
GRANT ALL ON FUNCTION "public"."gbtreekey_var_out"("public"."gbtreekey_var") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbtreekey_var_out"("public"."gbtreekey_var") TO "service_role";



REVOKE ALL ON FUNCTION "catalog"."rpc_mutate_tax_entity"("p_table_name" "text", "p_action" "text", "p_payload" "jsonb", "p_actor_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "catalog"."rpc_mutate_tax_entity"("p_table_name" "text", "p_action" "text", "p_payload" "jsonb", "p_actor_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "catalog"."validate_block_district_relationship"() FROM PUBLIC;



REVOKE ALL ON FUNCTION "data_imports"."trg_enforce_artifact_immutability"() FROM PUBLIC;






















































































































































REVOKE ALL ON FUNCTION "integration"."enqueue_webhook"("p_event_type" "text", "p_payload" "jsonb", "p_idempotency_key" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "integration"."enqueue_webhook"("p_event_type" "text", "p_payload" "jsonb", "p_idempotency_key" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."cash_dist"("money", "money") TO "postgres";
GRANT ALL ON FUNCTION "public"."cash_dist"("money", "money") TO "anon";
GRANT ALL ON FUNCTION "public"."cash_dist"("money", "money") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cash_dist"("money", "money") TO "service_role";



GRANT ALL ON FUNCTION "public"."date_dist"("date", "date") TO "postgres";
GRANT ALL ON FUNCTION "public"."date_dist"("date", "date") TO "anon";
GRANT ALL ON FUNCTION "public"."date_dist"("date", "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."date_dist"("date", "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."float4_dist"(real, real) TO "postgres";
GRANT ALL ON FUNCTION "public"."float4_dist"(real, real) TO "anon";
GRANT ALL ON FUNCTION "public"."float4_dist"(real, real) TO "authenticated";
GRANT ALL ON FUNCTION "public"."float4_dist"(real, real) TO "service_role";



GRANT ALL ON FUNCTION "public"."float8_dist"(double precision, double precision) TO "postgres";
GRANT ALL ON FUNCTION "public"."float8_dist"(double precision, double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."float8_dist"(double precision, double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."float8_dist"(double precision, double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_bit_compress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_bit_compress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_bit_compress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_bit_compress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_bit_consistent"("internal", bit, smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_bit_consistent"("internal", bit, smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_bit_consistent"("internal", bit, smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_bit_consistent"("internal", bit, smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_bit_penalty"("internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_bit_penalty"("internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_bit_penalty"("internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_bit_penalty"("internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_bit_picksplit"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_bit_picksplit"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_bit_picksplit"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_bit_picksplit"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_bit_same"("public"."gbtreekey_var", "public"."gbtreekey_var", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_bit_same"("public"."gbtreekey_var", "public"."gbtreekey_var", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_bit_same"("public"."gbtreekey_var", "public"."gbtreekey_var", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_bit_same"("public"."gbtreekey_var", "public"."gbtreekey_var", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_bit_union"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_bit_union"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_bit_union"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_bit_union"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_bool_compress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_bool_compress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_bool_compress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_bool_compress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_bool_consistent"("internal", boolean, smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_bool_consistent"("internal", boolean, smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_bool_consistent"("internal", boolean, smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_bool_consistent"("internal", boolean, smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_bool_fetch"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_bool_fetch"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_bool_fetch"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_bool_fetch"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_bool_penalty"("internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_bool_penalty"("internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_bool_penalty"("internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_bool_penalty"("internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_bool_picksplit"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_bool_picksplit"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_bool_picksplit"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_bool_picksplit"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_bool_same"("public"."gbtreekey2", "public"."gbtreekey2", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_bool_same"("public"."gbtreekey2", "public"."gbtreekey2", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_bool_same"("public"."gbtreekey2", "public"."gbtreekey2", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_bool_same"("public"."gbtreekey2", "public"."gbtreekey2", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_bool_union"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_bool_union"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_bool_union"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_bool_union"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_bpchar_compress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_bpchar_compress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_bpchar_compress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_bpchar_compress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_bpchar_consistent"("internal", character, smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_bpchar_consistent"("internal", character, smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_bpchar_consistent"("internal", character, smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_bpchar_consistent"("internal", character, smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_bytea_compress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_bytea_compress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_bytea_compress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_bytea_compress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_bytea_consistent"("internal", "bytea", smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_bytea_consistent"("internal", "bytea", smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_bytea_consistent"("internal", "bytea", smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_bytea_consistent"("internal", "bytea", smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_bytea_penalty"("internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_bytea_penalty"("internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_bytea_penalty"("internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_bytea_penalty"("internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_bytea_picksplit"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_bytea_picksplit"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_bytea_picksplit"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_bytea_picksplit"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_bytea_same"("public"."gbtreekey_var", "public"."gbtreekey_var", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_bytea_same"("public"."gbtreekey_var", "public"."gbtreekey_var", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_bytea_same"("public"."gbtreekey_var", "public"."gbtreekey_var", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_bytea_same"("public"."gbtreekey_var", "public"."gbtreekey_var", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_bytea_union"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_bytea_union"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_bytea_union"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_bytea_union"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_cash_compress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_cash_compress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_cash_compress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_cash_compress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_cash_consistent"("internal", "money", smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_cash_consistent"("internal", "money", smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_cash_consistent"("internal", "money", smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_cash_consistent"("internal", "money", smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_cash_distance"("internal", "money", smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_cash_distance"("internal", "money", smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_cash_distance"("internal", "money", smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_cash_distance"("internal", "money", smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_cash_fetch"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_cash_fetch"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_cash_fetch"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_cash_fetch"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_cash_penalty"("internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_cash_penalty"("internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_cash_penalty"("internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_cash_penalty"("internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_cash_picksplit"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_cash_picksplit"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_cash_picksplit"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_cash_picksplit"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_cash_same"("public"."gbtreekey16", "public"."gbtreekey16", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_cash_same"("public"."gbtreekey16", "public"."gbtreekey16", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_cash_same"("public"."gbtreekey16", "public"."gbtreekey16", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_cash_same"("public"."gbtreekey16", "public"."gbtreekey16", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_cash_union"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_cash_union"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_cash_union"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_cash_union"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_date_compress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_date_compress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_date_compress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_date_compress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_date_consistent"("internal", "date", smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_date_consistent"("internal", "date", smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_date_consistent"("internal", "date", smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_date_consistent"("internal", "date", smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_date_distance"("internal", "date", smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_date_distance"("internal", "date", smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_date_distance"("internal", "date", smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_date_distance"("internal", "date", smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_date_fetch"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_date_fetch"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_date_fetch"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_date_fetch"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_date_penalty"("internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_date_penalty"("internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_date_penalty"("internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_date_penalty"("internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_date_picksplit"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_date_picksplit"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_date_picksplit"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_date_picksplit"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_date_same"("public"."gbtreekey8", "public"."gbtreekey8", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_date_same"("public"."gbtreekey8", "public"."gbtreekey8", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_date_same"("public"."gbtreekey8", "public"."gbtreekey8", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_date_same"("public"."gbtreekey8", "public"."gbtreekey8", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_date_union"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_date_union"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_date_union"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_date_union"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_decompress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_decompress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_decompress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_decompress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_enum_compress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_enum_compress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_enum_compress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_enum_compress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_enum_consistent"("internal", "anyenum", smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_enum_consistent"("internal", "anyenum", smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_enum_consistent"("internal", "anyenum", smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_enum_consistent"("internal", "anyenum", smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_enum_fetch"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_enum_fetch"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_enum_fetch"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_enum_fetch"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_enum_penalty"("internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_enum_penalty"("internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_enum_penalty"("internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_enum_penalty"("internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_enum_picksplit"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_enum_picksplit"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_enum_picksplit"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_enum_picksplit"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_enum_same"("public"."gbtreekey8", "public"."gbtreekey8", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_enum_same"("public"."gbtreekey8", "public"."gbtreekey8", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_enum_same"("public"."gbtreekey8", "public"."gbtreekey8", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_enum_same"("public"."gbtreekey8", "public"."gbtreekey8", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_enum_union"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_enum_union"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_enum_union"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_enum_union"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_float4_compress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_float4_compress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_float4_compress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_float4_compress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_float4_consistent"("internal", real, smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_float4_consistent"("internal", real, smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_float4_consistent"("internal", real, smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_float4_consistent"("internal", real, smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_float4_distance"("internal", real, smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_float4_distance"("internal", real, smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_float4_distance"("internal", real, smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_float4_distance"("internal", real, smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_float4_fetch"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_float4_fetch"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_float4_fetch"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_float4_fetch"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_float4_penalty"("internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_float4_penalty"("internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_float4_penalty"("internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_float4_penalty"("internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_float4_picksplit"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_float4_picksplit"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_float4_picksplit"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_float4_picksplit"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_float4_same"("public"."gbtreekey8", "public"."gbtreekey8", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_float4_same"("public"."gbtreekey8", "public"."gbtreekey8", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_float4_same"("public"."gbtreekey8", "public"."gbtreekey8", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_float4_same"("public"."gbtreekey8", "public"."gbtreekey8", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_float4_union"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_float4_union"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_float4_union"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_float4_union"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_float8_compress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_float8_compress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_float8_compress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_float8_compress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_float8_consistent"("internal", double precision, smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_float8_consistent"("internal", double precision, smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_float8_consistent"("internal", double precision, smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_float8_consistent"("internal", double precision, smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_float8_distance"("internal", double precision, smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_float8_distance"("internal", double precision, smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_float8_distance"("internal", double precision, smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_float8_distance"("internal", double precision, smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_float8_fetch"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_float8_fetch"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_float8_fetch"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_float8_fetch"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_float8_penalty"("internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_float8_penalty"("internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_float8_penalty"("internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_float8_penalty"("internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_float8_picksplit"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_float8_picksplit"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_float8_picksplit"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_float8_picksplit"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_float8_same"("public"."gbtreekey16", "public"."gbtreekey16", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_float8_same"("public"."gbtreekey16", "public"."gbtreekey16", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_float8_same"("public"."gbtreekey16", "public"."gbtreekey16", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_float8_same"("public"."gbtreekey16", "public"."gbtreekey16", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_float8_union"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_float8_union"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_float8_union"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_float8_union"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_inet_compress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_inet_compress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_inet_compress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_inet_compress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_inet_consistent"("internal", "inet", smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_inet_consistent"("internal", "inet", smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_inet_consistent"("internal", "inet", smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_inet_consistent"("internal", "inet", smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_inet_penalty"("internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_inet_penalty"("internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_inet_penalty"("internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_inet_penalty"("internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_inet_picksplit"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_inet_picksplit"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_inet_picksplit"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_inet_picksplit"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_inet_same"("public"."gbtreekey16", "public"."gbtreekey16", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_inet_same"("public"."gbtreekey16", "public"."gbtreekey16", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_inet_same"("public"."gbtreekey16", "public"."gbtreekey16", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_inet_same"("public"."gbtreekey16", "public"."gbtreekey16", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_inet_union"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_inet_union"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_inet_union"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_inet_union"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_int2_compress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_int2_compress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_int2_compress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_int2_compress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_int2_consistent"("internal", smallint, smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_int2_consistent"("internal", smallint, smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_int2_consistent"("internal", smallint, smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_int2_consistent"("internal", smallint, smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_int2_distance"("internal", smallint, smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_int2_distance"("internal", smallint, smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_int2_distance"("internal", smallint, smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_int2_distance"("internal", smallint, smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_int2_fetch"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_int2_fetch"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_int2_fetch"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_int2_fetch"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_int2_penalty"("internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_int2_penalty"("internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_int2_penalty"("internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_int2_penalty"("internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_int2_picksplit"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_int2_picksplit"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_int2_picksplit"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_int2_picksplit"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_int2_same"("public"."gbtreekey4", "public"."gbtreekey4", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_int2_same"("public"."gbtreekey4", "public"."gbtreekey4", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_int2_same"("public"."gbtreekey4", "public"."gbtreekey4", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_int2_same"("public"."gbtreekey4", "public"."gbtreekey4", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_int2_union"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_int2_union"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_int2_union"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_int2_union"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_int4_compress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_int4_compress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_int4_compress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_int4_compress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_int4_consistent"("internal", integer, smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_int4_consistent"("internal", integer, smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_int4_consistent"("internal", integer, smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_int4_consistent"("internal", integer, smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_int4_distance"("internal", integer, smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_int4_distance"("internal", integer, smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_int4_distance"("internal", integer, smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_int4_distance"("internal", integer, smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_int4_fetch"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_int4_fetch"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_int4_fetch"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_int4_fetch"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_int4_penalty"("internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_int4_penalty"("internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_int4_penalty"("internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_int4_penalty"("internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_int4_picksplit"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_int4_picksplit"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_int4_picksplit"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_int4_picksplit"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_int4_same"("public"."gbtreekey8", "public"."gbtreekey8", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_int4_same"("public"."gbtreekey8", "public"."gbtreekey8", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_int4_same"("public"."gbtreekey8", "public"."gbtreekey8", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_int4_same"("public"."gbtreekey8", "public"."gbtreekey8", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_int4_union"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_int4_union"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_int4_union"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_int4_union"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_int8_compress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_int8_compress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_int8_compress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_int8_compress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_int8_consistent"("internal", bigint, smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_int8_consistent"("internal", bigint, smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_int8_consistent"("internal", bigint, smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_int8_consistent"("internal", bigint, smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_int8_distance"("internal", bigint, smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_int8_distance"("internal", bigint, smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_int8_distance"("internal", bigint, smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_int8_distance"("internal", bigint, smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_int8_fetch"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_int8_fetch"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_int8_fetch"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_int8_fetch"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_int8_penalty"("internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_int8_penalty"("internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_int8_penalty"("internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_int8_penalty"("internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_int8_picksplit"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_int8_picksplit"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_int8_picksplit"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_int8_picksplit"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_int8_same"("public"."gbtreekey16", "public"."gbtreekey16", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_int8_same"("public"."gbtreekey16", "public"."gbtreekey16", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_int8_same"("public"."gbtreekey16", "public"."gbtreekey16", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_int8_same"("public"."gbtreekey16", "public"."gbtreekey16", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_int8_union"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_int8_union"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_int8_union"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_int8_union"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_intv_compress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_intv_compress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_intv_compress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_intv_compress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_intv_consistent"("internal", interval, smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_intv_consistent"("internal", interval, smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_intv_consistent"("internal", interval, smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_intv_consistent"("internal", interval, smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_intv_decompress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_intv_decompress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_intv_decompress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_intv_decompress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_intv_distance"("internal", interval, smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_intv_distance"("internal", interval, smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_intv_distance"("internal", interval, smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_intv_distance"("internal", interval, smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_intv_fetch"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_intv_fetch"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_intv_fetch"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_intv_fetch"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_intv_penalty"("internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_intv_penalty"("internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_intv_penalty"("internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_intv_penalty"("internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_intv_picksplit"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_intv_picksplit"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_intv_picksplit"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_intv_picksplit"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_intv_same"("public"."gbtreekey32", "public"."gbtreekey32", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_intv_same"("public"."gbtreekey32", "public"."gbtreekey32", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_intv_same"("public"."gbtreekey32", "public"."gbtreekey32", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_intv_same"("public"."gbtreekey32", "public"."gbtreekey32", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_intv_union"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_intv_union"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_intv_union"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_intv_union"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_macad8_compress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_macad8_compress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_macad8_compress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_macad8_compress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_macad8_consistent"("internal", "macaddr8", smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_macad8_consistent"("internal", "macaddr8", smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_macad8_consistent"("internal", "macaddr8", smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_macad8_consistent"("internal", "macaddr8", smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_macad8_fetch"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_macad8_fetch"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_macad8_fetch"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_macad8_fetch"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_macad8_penalty"("internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_macad8_penalty"("internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_macad8_penalty"("internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_macad8_penalty"("internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_macad8_picksplit"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_macad8_picksplit"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_macad8_picksplit"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_macad8_picksplit"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_macad8_same"("public"."gbtreekey16", "public"."gbtreekey16", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_macad8_same"("public"."gbtreekey16", "public"."gbtreekey16", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_macad8_same"("public"."gbtreekey16", "public"."gbtreekey16", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_macad8_same"("public"."gbtreekey16", "public"."gbtreekey16", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_macad8_union"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_macad8_union"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_macad8_union"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_macad8_union"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_macad_compress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_macad_compress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_macad_compress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_macad_compress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_macad_consistent"("internal", "macaddr", smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_macad_consistent"("internal", "macaddr", smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_macad_consistent"("internal", "macaddr", smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_macad_consistent"("internal", "macaddr", smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_macad_fetch"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_macad_fetch"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_macad_fetch"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_macad_fetch"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_macad_penalty"("internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_macad_penalty"("internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_macad_penalty"("internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_macad_penalty"("internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_macad_picksplit"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_macad_picksplit"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_macad_picksplit"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_macad_picksplit"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_macad_same"("public"."gbtreekey16", "public"."gbtreekey16", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_macad_same"("public"."gbtreekey16", "public"."gbtreekey16", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_macad_same"("public"."gbtreekey16", "public"."gbtreekey16", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_macad_same"("public"."gbtreekey16", "public"."gbtreekey16", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_macad_union"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_macad_union"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_macad_union"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_macad_union"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_numeric_compress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_numeric_compress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_numeric_compress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_numeric_compress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_numeric_consistent"("internal", numeric, smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_numeric_consistent"("internal", numeric, smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_numeric_consistent"("internal", numeric, smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_numeric_consistent"("internal", numeric, smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_numeric_penalty"("internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_numeric_penalty"("internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_numeric_penalty"("internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_numeric_penalty"("internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_numeric_picksplit"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_numeric_picksplit"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_numeric_picksplit"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_numeric_picksplit"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_numeric_same"("public"."gbtreekey_var", "public"."gbtreekey_var", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_numeric_same"("public"."gbtreekey_var", "public"."gbtreekey_var", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_numeric_same"("public"."gbtreekey_var", "public"."gbtreekey_var", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_numeric_same"("public"."gbtreekey_var", "public"."gbtreekey_var", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_numeric_union"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_numeric_union"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_numeric_union"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_numeric_union"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_oid_compress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_oid_compress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_oid_compress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_oid_compress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_oid_consistent"("internal", "oid", smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_oid_consistent"("internal", "oid", smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_oid_consistent"("internal", "oid", smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_oid_consistent"("internal", "oid", smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_oid_distance"("internal", "oid", smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_oid_distance"("internal", "oid", smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_oid_distance"("internal", "oid", smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_oid_distance"("internal", "oid", smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_oid_fetch"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_oid_fetch"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_oid_fetch"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_oid_fetch"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_oid_penalty"("internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_oid_penalty"("internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_oid_penalty"("internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_oid_penalty"("internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_oid_picksplit"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_oid_picksplit"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_oid_picksplit"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_oid_picksplit"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_oid_same"("public"."gbtreekey8", "public"."gbtreekey8", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_oid_same"("public"."gbtreekey8", "public"."gbtreekey8", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_oid_same"("public"."gbtreekey8", "public"."gbtreekey8", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_oid_same"("public"."gbtreekey8", "public"."gbtreekey8", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_oid_union"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_oid_union"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_oid_union"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_oid_union"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_text_compress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_text_compress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_text_compress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_text_compress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_text_consistent"("internal", "text", smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_text_consistent"("internal", "text", smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_text_consistent"("internal", "text", smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_text_consistent"("internal", "text", smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_text_penalty"("internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_text_penalty"("internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_text_penalty"("internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_text_penalty"("internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_text_picksplit"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_text_picksplit"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_text_picksplit"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_text_picksplit"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_text_same"("public"."gbtreekey_var", "public"."gbtreekey_var", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_text_same"("public"."gbtreekey_var", "public"."gbtreekey_var", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_text_same"("public"."gbtreekey_var", "public"."gbtreekey_var", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_text_same"("public"."gbtreekey_var", "public"."gbtreekey_var", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_text_union"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_text_union"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_text_union"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_text_union"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_time_compress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_time_compress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_time_compress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_time_compress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_time_consistent"("internal", time without time zone, smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_time_consistent"("internal", time without time zone, smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_time_consistent"("internal", time without time zone, smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_time_consistent"("internal", time without time zone, smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_time_distance"("internal", time without time zone, smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_time_distance"("internal", time without time zone, smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_time_distance"("internal", time without time zone, smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_time_distance"("internal", time without time zone, smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_time_fetch"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_time_fetch"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_time_fetch"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_time_fetch"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_time_penalty"("internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_time_penalty"("internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_time_penalty"("internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_time_penalty"("internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_time_picksplit"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_time_picksplit"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_time_picksplit"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_time_picksplit"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_time_same"("public"."gbtreekey16", "public"."gbtreekey16", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_time_same"("public"."gbtreekey16", "public"."gbtreekey16", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_time_same"("public"."gbtreekey16", "public"."gbtreekey16", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_time_same"("public"."gbtreekey16", "public"."gbtreekey16", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_time_union"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_time_union"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_time_union"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_time_union"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_timetz_compress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_timetz_compress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_timetz_compress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_timetz_compress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_timetz_consistent"("internal", time with time zone, smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_timetz_consistent"("internal", time with time zone, smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_timetz_consistent"("internal", time with time zone, smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_timetz_consistent"("internal", time with time zone, smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_ts_compress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_ts_compress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_ts_compress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_ts_compress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_ts_consistent"("internal", timestamp without time zone, smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_ts_consistent"("internal", timestamp without time zone, smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_ts_consistent"("internal", timestamp without time zone, smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_ts_consistent"("internal", timestamp without time zone, smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_ts_distance"("internal", timestamp without time zone, smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_ts_distance"("internal", timestamp without time zone, smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_ts_distance"("internal", timestamp without time zone, smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_ts_distance"("internal", timestamp without time zone, smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_ts_fetch"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_ts_fetch"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_ts_fetch"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_ts_fetch"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_ts_penalty"("internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_ts_penalty"("internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_ts_penalty"("internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_ts_penalty"("internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_ts_picksplit"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_ts_picksplit"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_ts_picksplit"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_ts_picksplit"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_ts_same"("public"."gbtreekey16", "public"."gbtreekey16", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_ts_same"("public"."gbtreekey16", "public"."gbtreekey16", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_ts_same"("public"."gbtreekey16", "public"."gbtreekey16", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_ts_same"("public"."gbtreekey16", "public"."gbtreekey16", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_ts_union"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_ts_union"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_ts_union"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_ts_union"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_tstz_compress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_tstz_compress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_tstz_compress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_tstz_compress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_tstz_consistent"("internal", timestamp with time zone, smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_tstz_consistent"("internal", timestamp with time zone, smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_tstz_consistent"("internal", timestamp with time zone, smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_tstz_consistent"("internal", timestamp with time zone, smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_tstz_distance"("internal", timestamp with time zone, smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_tstz_distance"("internal", timestamp with time zone, smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_tstz_distance"("internal", timestamp with time zone, smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_tstz_distance"("internal", timestamp with time zone, smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_uuid_compress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_uuid_compress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_uuid_compress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_uuid_compress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_uuid_consistent"("internal", "uuid", smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_uuid_consistent"("internal", "uuid", smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_uuid_consistent"("internal", "uuid", smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_uuid_consistent"("internal", "uuid", smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_uuid_fetch"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_uuid_fetch"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_uuid_fetch"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_uuid_fetch"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_uuid_penalty"("internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_uuid_penalty"("internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_uuid_penalty"("internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_uuid_penalty"("internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_uuid_picksplit"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_uuid_picksplit"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_uuid_picksplit"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_uuid_picksplit"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_uuid_same"("public"."gbtreekey32", "public"."gbtreekey32", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_uuid_same"("public"."gbtreekey32", "public"."gbtreekey32", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_uuid_same"("public"."gbtreekey32", "public"."gbtreekey32", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_uuid_same"("public"."gbtreekey32", "public"."gbtreekey32", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_uuid_union"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_uuid_union"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_uuid_union"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_uuid_union"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_var_decompress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_var_decompress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_var_decompress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_var_decompress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gbt_var_fetch"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gbt_var_fetch"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gbt_var_fetch"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gbt_var_fetch"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."int2_dist"(smallint, smallint) TO "postgres";
GRANT ALL ON FUNCTION "public"."int2_dist"(smallint, smallint) TO "anon";
GRANT ALL ON FUNCTION "public"."int2_dist"(smallint, smallint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."int2_dist"(smallint, smallint) TO "service_role";



GRANT ALL ON FUNCTION "public"."int4_dist"(integer, integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."int4_dist"(integer, integer) TO "anon";
GRANT ALL ON FUNCTION "public"."int4_dist"(integer, integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."int4_dist"(integer, integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."int8_dist"(bigint, bigint) TO "postgres";
GRANT ALL ON FUNCTION "public"."int8_dist"(bigint, bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."int8_dist"(bigint, bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."int8_dist"(bigint, bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."interval_dist"(interval, interval) TO "postgres";
GRANT ALL ON FUNCTION "public"."interval_dist"(interval, interval) TO "anon";
GRANT ALL ON FUNCTION "public"."interval_dist"(interval, interval) TO "authenticated";
GRANT ALL ON FUNCTION "public"."interval_dist"(interval, interval) TO "service_role";



GRANT ALL ON FUNCTION "public"."oid_dist"("oid", "oid") TO "postgres";
GRANT ALL ON FUNCTION "public"."oid_dist"("oid", "oid") TO "anon";
GRANT ALL ON FUNCTION "public"."oid_dist"("oid", "oid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."oid_dist"("oid", "oid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."resolve_platform_staff_authority"("p_auth_user_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."resolve_platform_staff_authority"("p_auth_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."rls_auto_enable"() TO "anon";
GRANT ALL ON FUNCTION "public"."rls_auto_enable"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."rls_auto_enable"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."rpc_create_country"("p_iso2" "text", "p_iso3" "text", "p_numeric_code" "text", "p_official_name" "text", "p_display_name" "text", "p_default_currency_code" "text", "p_staff_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."rpc_create_country"("p_iso2" "text", "p_iso3" "text", "p_numeric_code" "text", "p_official_name" "text", "p_display_name" "text", "p_default_currency_code" "text", "p_staff_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."rpc_create_level"("p_country_id" "uuid", "p_level_number" integer, "p_level_key" "text", "p_display_label" "text", "p_staff_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."rpc_create_level"("p_country_id" "uuid", "p_level_number" integer, "p_level_key" "text", "p_display_label" "text", "p_staff_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."rpc_create_postal_code"("p_country_id" "uuid", "p_postal_code" "text", "p_staff_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."rpc_create_postal_code"("p_country_id" "uuid", "p_postal_code" "text", "p_staff_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."rpc_create_unit"("p_country_id" "uuid", "p_geography_level_id" "uuid", "p_parent_geography_unit_id" "uuid", "p_official_code" "text", "p_iso_subdivision_code" "text", "p_official_name" "text", "p_display_name" "text", "p_staff_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."rpc_create_unit"("p_country_id" "uuid", "p_geography_level_id" "uuid", "p_parent_geography_unit_id" "uuid", "p_official_code" "text", "p_iso_subdivision_code" "text", "p_official_name" "text", "p_display_name" "text", "p_staff_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."rpc_get_countries"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."rpc_get_countries"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."rpc_get_country_currencies"("p_iso2" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."rpc_get_country_currencies"("p_iso2" "text") TO "service_role";



GRANT ALL ON TABLE "catalog"."currencies" TO "service_role";



REVOKE ALL ON FUNCTION "public"."rpc_get_currencies"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."rpc_get_currencies"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."rpc_get_development_blocks"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."rpc_get_development_blocks"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."rpc_get_levels"("p_country_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."rpc_get_levels"("p_country_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."rpc_get_postal_codes"("p_country_id" "uuid", "p_status" "text", "p_search" "text", "p_limit" integer, "p_offset" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."rpc_get_postal_codes"("p_country_id" "uuid", "p_status" "text", "p_search" "text", "p_limit" integer, "p_offset" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."rpc_get_units"("p_country_id" "uuid", "p_level_id" "uuid", "p_parent_id" "uuid", "p_status" "text", "p_search" "text", "p_limit" integer, "p_offset" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."rpc_get_units"("p_country_id" "uuid", "p_level_id" "uuid", "p_parent_id" "uuid", "p_status" "text", "p_search" "text", "p_limit" integer, "p_offset" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."rpc_set_postal_mappings"("p_postal_code_id" "uuid", "p_geography_unit_ids" "uuid"[], "p_staff_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."rpc_set_postal_mappings"("p_postal_code_id" "uuid", "p_geography_unit_ids" "uuid"[], "p_staff_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."rpc_update_country"("p_id" "uuid", "p_official_name" "text", "p_display_name" "text", "p_default_currency_code" "text", "p_status" "text", "p_staff_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."rpc_update_country"("p_id" "uuid", "p_official_name" "text", "p_display_name" "text", "p_default_currency_code" "text", "p_status" "text", "p_staff_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."rpc_update_level"("p_id" "uuid", "p_display_label" "text", "p_status" "text", "p_staff_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."rpc_update_level"("p_id" "uuid", "p_display_label" "text", "p_status" "text", "p_staff_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."rpc_update_postal_code"("p_id" "uuid", "p_postal_code" "text", "p_status" "text", "p_staff_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."rpc_update_postal_code"("p_id" "uuid", "p_postal_code" "text", "p_status" "text", "p_staff_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."rpc_update_unit"("p_id" "uuid", "p_official_name" "text", "p_display_name" "text", "p_iso_subdivision_code" "text", "p_status" "text", "p_staff_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."rpc_update_unit"("p_id" "uuid", "p_official_name" "text", "p_display_name" "text", "p_iso_subdivision_code" "text", "p_status" "text", "p_staff_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."rpc_write_audit"("p_staff_id" "uuid", "p_action" "text", "p_resource" "text", "p_resource_id" "uuid", "p_payload" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."rpc_write_audit"("p_staff_id" "uuid", "p_action" "text", "p_resource" "text", "p_resource_id" "uuid", "p_payload" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."time_dist"(time without time zone, time without time zone) TO "postgres";
GRANT ALL ON FUNCTION "public"."time_dist"(time without time zone, time without time zone) TO "anon";
GRANT ALL ON FUNCTION "public"."time_dist"(time without time zone, time without time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."time_dist"(time without time zone, time without time zone) TO "service_role";



GRANT ALL ON FUNCTION "public"."ts_dist"(timestamp without time zone, timestamp without time zone) TO "postgres";
GRANT ALL ON FUNCTION "public"."ts_dist"(timestamp without time zone, timestamp without time zone) TO "anon";
GRANT ALL ON FUNCTION "public"."ts_dist"(timestamp without time zone, timestamp without time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."ts_dist"(timestamp without time zone, timestamp without time zone) TO "service_role";



GRANT ALL ON FUNCTION "public"."tstz_dist"(timestamp with time zone, timestamp with time zone) TO "postgres";
GRANT ALL ON FUNCTION "public"."tstz_dist"(timestamp with time zone, timestamp with time zone) TO "anon";
GRANT ALL ON FUNCTION "public"."tstz_dist"(timestamp with time zone, timestamp with time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."tstz_dist"(timestamp with time zone, timestamp with time zone) TO "service_role";



REVOKE ALL ON FUNCTION "staging"."trg_enforce_geography_import_identity"() FROM PUBLIC;












GRANT ALL ON TABLE "audit"."publication_history" TO "service_role";



GRANT ALL ON TABLE "audit"."staff_events" TO "service_role";



GRANT ALL ON TABLE "billing"."entitlements" TO "service_role";



GRANT ALL ON TABLE "billing"."invoices" TO "service_role";



GRANT ALL ON TABLE "billing"."payment_webhook_events" TO "service_role";



GRANT ALL ON TABLE "billing"."plans" TO "service_role";



GRANT ALL ON TABLE "billing"."subscriptions" TO "service_role";



GRANT SELECT ON TABLE "catalog"."block_districts" TO "service_role";



GRANT ALL ON TABLE "catalog"."catalog_release_items" TO "service_role";



GRANT ALL ON TABLE "catalog"."catalog_releases" TO "service_role";



GRANT ALL ON TABLE "catalog"."country_tax_coverage" TO "service_role";



GRANT SELECT ON TABLE "catalog"."development_blocks" TO "service_role";



GRANT ALL ON TABLE "catalog"."geo_masters" TO "service_role";



GRANT ALL ON TABLE "catalog"."hsn_sac" TO "service_role";



GRANT ALL ON TABLE "catalog"."jurisdictions" TO "service_role";



GRANT ALL ON TABLE "catalog"."tax_authorities" TO "service_role";



GRANT ALL ON TABLE "catalog"."tax_codes" TO "service_role";



GRANT ALL ON TABLE "catalog"."tax_rates" TO "service_role";



GRANT ALL ON TABLE "catalog"."uqc" TO "service_role";



GRANT SELECT ON TABLE "data_imports"."batches" TO "service_role";



GRANT SELECT ON TABLE "data_imports"."release_execution_artifacts" TO "service_role";



GRANT SELECT ON TABLE "data_imports"."releases" TO "service_role";



GRANT SELECT ON TABLE "data_imports"."row_errors" TO "service_role";









GRANT ALL ON TABLE "integration"."delivery_attempts" TO "service_role";



GRANT ALL ON TABLE "integration"."idempotency_records" TO "service_role";



GRANT ALL ON TABLE "integration"."outbox_events" TO "service_role";



GRANT ALL ON TABLE "integration"."webhook_endpoints" TO "service_role";



GRANT ALL ON TABLE "platform"."account_owners" TO "service_role";



GRANT ALL ON TABLE "platform"."platform_accounts" TO "service_role";



GRANT ALL ON TABLE "platform"."platform_staff" TO "service_role";



GRANT ALL ON TABLE "platform"."provisioning_jobs" TO "service_role";



GRANT ALL ON TABLE "platform"."tenant_registry" TO "service_role";



GRANT SELECT ON TABLE "staging"."geography_imports" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";



































