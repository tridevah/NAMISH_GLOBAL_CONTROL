BEGIN;

CREATE TABLE catalog.measurement_units (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    canonical_code TEXT UNIQUE NOT NULL,
    standard_code TEXT,
    name TEXT NOT NULL,
    symbol TEXT,
    category TEXT NOT NULL,
    aliases TEXT[] DEFAULT '{}',
    status TEXT DEFAULT 'ACTIVE',
    source_status TEXT,
    source TEXT NOT NULL,
    source_version TEXT,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE catalog.measurement_units ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog.measurement_units FORCE ROW LEVEL SECURITY;
CREATE POLICY "Service Role Access" ON catalog.measurement_units FOR ALL USING (auth.role() = 'service_role');

-- FK Guard
DO $$
DECLARE
    v_col_num smallint;
    v_target_col_num smallint;
    v_fk record;
    v_fk_count int := 0;
    v_type text;
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='catalog' AND table_name='uqc' AND column_name='measurement_unit_id') THEN
        SELECT data_type INTO v_type FROM information_schema.columns WHERE table_schema='catalog' AND table_name='uqc' AND column_name='measurement_unit_id';
        IF v_type != 'uuid' THEN RAISE EXCEPTION 'catalog.uqc.measurement_unit_id exists but is not UUID'; END IF;
    ELSE
        ALTER TABLE catalog.uqc ADD COLUMN measurement_unit_id UUID;
    END IF;

    SELECT attnum INTO v_col_num FROM pg_attribute WHERE attrelid = 'catalog.uqc'::regclass AND attname = 'measurement_unit_id';
    SELECT attnum INTO v_target_col_num FROM pg_attribute WHERE attrelid = 'catalog.measurement_units'::regclass AND attname = 'id';

    FOR v_fk IN (
        SELECT c.conname, c.confdeltype, c.confrelid, c.conkey, c.confkey
        FROM pg_constraint c
        WHERE c.conrelid = 'catalog.uqc'::regclass AND c.contype = 'f' AND v_col_num = ANY(c.conkey)
    ) LOOP
        v_fk_count := v_fk_count + 1;
        IF array_length(v_fk.conkey, 1) != 1 OR array_length(v_fk.confkey, 1) != 1 THEN
            RAISE EXCEPTION 'FK % uses multiple columns', v_fk.conname;
        END IF;
        IF v_fk.confrelid != 'catalog.measurement_units'::regclass THEN
            RAISE EXCEPTION 'FK % targets wrong relation OID', v_fk.conname;
        END IF;
        IF v_fk.confkey[1] != v_target_col_num THEN
            RAISE EXCEPTION 'FK % targets wrong column in measurement_units', v_fk.conname;
        END IF;
        IF v_fk.confdeltype != 'n' THEN
            RAISE EXCEPTION 'FK % delete action is not SET NULL', v_fk.conname;
        END IF;
    END LOOP;

    IF v_fk_count > 1 THEN
        RAISE EXCEPTION 'Multiple FKs found for catalog.uqc.measurement_unit_id';
    END IF;

    IF v_fk_count = 0 THEN
        ALTER TABLE catalog.uqc ADD CONSTRAINT uqc_measurement_unit_id_fkey FOREIGN KEY (measurement_unit_id) REFERENCES catalog.measurement_units(id) ON DELETE SET NULL;
    END IF;
END $$;

CREATE TABLE catalog.unit_conversions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_unit_id UUID NOT NULL REFERENCES catalog.measurement_units(id) ON DELETE CASCADE,
    to_unit_id UUID NOT NULL REFERENCES catalog.measurement_units(id) ON DELETE CASCADE,
    multiplier NUMERIC NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(from_unit_id, to_unit_id)
);

ALTER TABLE catalog.unit_conversions ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog.unit_conversions FORCE ROW LEVEL SECURITY;
CREATE POLICY "Service Role Access" ON catalog.unit_conversions FOR ALL USING (auth.role() = 'service_role');

CREATE OR REPLACE VIEW public.measurement_units AS SELECT * FROM catalog.measurement_units;
CREATE OR REPLACE VIEW public.unit_conversions AS SELECT * FROM catalog.unit_conversions;

REVOKE ALL ON public.measurement_units, public.unit_conversions FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON public.measurement_units, public.unit_conversions TO service_role;

CREATE OR REPLACE FUNCTION catalog.import_unit_master_impl(
    p_units JSONB, p_uqc_mappings JSONB, p_conversions JSONB
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = catalog, public, pg_temp
AS $$
DECLARE
    v_unit JSONB; v_uqc_map JSONB; v_conv JSONB;
    v_unit_id UUID; v_from_id UUID; v_to_id UUID; v_existing_mult NUMERIC;
    v_units_inserted INT := 0; v_units_unchanged INT := 0;
    v_uqc_mapped INT := 0; v_uqc_unchanged INT := 0; v_uqc_unmapped INT := 0;
    v_conv_inserted INT := 0; v_conv_unchanged INT := 0;
    v_existing_row catalog.measurement_units%ROWTYPE;
    v_existing_uqc catalog.uqc%ROWTYPE;
BEGIN
    IF jsonb_typeof(p_units) IS DISTINCT FROM 'array' OR jsonb_typeof(p_uqc_mappings) IS DISTINCT FROM 'array' OR jsonb_typeof(p_conversions) IS DISTINCT FROM 'array' THEN
        RAISE EXCEPTION 'Import arguments must be non-null JSON arrays';
    END IF;
    
    IF (SELECT count(canonical_code) != count(DISTINCT canonical_code) FROM (SELECT jsonb_array_elements(p_units)->>'canonical_code' AS canonical_code) t) THEN
        RAISE EXCEPTION 'Input Validation Error: duplicate canonical_codes in p_units';
    END IF;
    
    IF (SELECT count(uqc_code) != count(DISTINCT uqc_code) FROM (SELECT jsonb_array_elements(p_uqc_mappings)->>'uqc_code' AS uqc_code) t) THEN
        RAISE EXCEPTION 'Input Validation Error: duplicate uqc_codes in p_uqc_mappings';
    END IF;

    FOR v_unit IN SELECT * FROM jsonb_array_elements(p_units) LOOP
        IF COALESCE(v_unit->>'canonical_code', '') = '' OR COALESCE(v_unit->>'standard_code', '') = '' OR COALESCE(v_unit->>'name', '') = '' OR COALESCE(v_unit->>'category', '') = '' OR COALESCE(v_unit->>'source', '') = '' THEN
            RAISE EXCEPTION 'Input Validation Error: Missing required non-empty string fields in unit definition';
        END IF;
        
        IF (v_unit->>'status') IS NULL OR (v_unit->>'status') NOT IN ('ACTIVE', 'INACTIVE') THEN
            RAISE EXCEPTION 'Input Validation Error: Invalid status % for unit %', (v_unit->>'status'), (v_unit->>'canonical_code');
        END IF;
        
        SELECT * INTO v_existing_row FROM catalog.measurement_units WHERE canonical_code = (v_unit->>'canonical_code');
        IF FOUND THEN
            IF v_existing_row.standard_code IS NOT DISTINCT FROM (v_unit->>'standard_code') AND
               v_existing_row.name IS NOT DISTINCT FROM (v_unit->>'name') AND
               v_existing_row.symbol IS NOT DISTINCT FROM (v_unit->>'symbol') AND
               v_existing_row.category IS NOT DISTINCT FROM (v_unit->>'category') AND
               v_existing_row.source_status IS NOT DISTINCT FROM (v_unit->>'source_status') AND
               v_existing_row.status IS NOT DISTINCT FROM (v_unit->>'status') AND
               v_existing_row.description IS NOT DISTINCT FROM (v_unit->>'description') AND
               v_existing_row.source IS NOT DISTINCT FROM (v_unit->>'source') AND
               v_existing_row.source_version IS NOT DISTINCT FROM (v_unit->>'source_version') THEN
                v_units_unchanged := v_units_unchanged + 1;
            ELSE
                RAISE EXCEPTION 'Unreviewed Overwrite Conflict: unit % differs from existing definition', (v_unit->>'canonical_code');
            END IF;
        ELSE
            INSERT INTO catalog.measurement_units (canonical_code, standard_code, name, symbol, category, source_status, status, source, source_version, description) 
            VALUES (v_unit->>'canonical_code', v_unit->>'standard_code', v_unit->>'name', v_unit->>'symbol', v_unit->>'category', v_unit->>'source_status', v_unit->>'status', v_unit->>'source', v_unit->>'source_version', v_unit->>'description');
            v_units_inserted := v_units_inserted + 1;
        END IF;
    END LOOP;

    FOR v_conv IN SELECT * FROM jsonb_array_elements(p_conversions) LOOP
        IF jsonb_typeof(v_conv->'multiplier') IS DISTINCT FROM 'number' THEN
            RAISE EXCEPTION 'Input Validation Error: multiplier must be a JSON number';
        END IF;
        IF (v_conv->>'multiplier')::NUMERIC <= 0 THEN
            RAISE EXCEPTION 'Input Validation Error: multiplier must be greater than zero';
        END IF;

        SELECT id INTO v_from_id FROM catalog.measurement_units WHERE canonical_code = 'UNECE_REC20_' || (v_conv->>'from_code');
        SELECT id INTO v_to_id FROM catalog.measurement_units WHERE canonical_code = 'UNECE_REC20_' || (v_conv->>'to_code');
        IF v_from_id IS NULL OR v_to_id IS NULL THEN
            RAISE EXCEPTION 'Invalid conversion codes: % -> %', (v_conv->>'from_code'), (v_conv->>'to_code');
        END IF;
        
        SELECT multiplier INTO v_existing_mult FROM catalog.unit_conversions WHERE from_unit_id = v_from_id AND to_unit_id = v_to_id;
        IF FOUND THEN
            IF v_existing_mult = (v_conv->>'multiplier')::NUMERIC THEN
                v_conv_unchanged := v_conv_unchanged + 1;
            ELSE
                RAISE EXCEPTION 'Unreviewed Overwrite Conflict: conversion multiplier % -> % differs from existing', (v_conv->>'from_code'), (v_conv->>'to_code');
            END IF;
        ELSE
            INSERT INTO catalog.unit_conversions (from_unit_id, to_unit_id, multiplier) VALUES (v_from_id, v_to_id, (v_conv->>'multiplier')::NUMERIC);
            v_conv_inserted := v_conv_inserted + 1;
        END IF;
    END LOOP;

    FOR v_uqc_map IN SELECT * FROM jsonb_array_elements(p_uqc_mappings) LOOP
        IF (v_uqc_map->>'outcome') IS NULL OR (v_uqc_map->>'outcome') NOT IN ('MAPPED', 'UNMAPPED') THEN
            RAISE EXCEPTION 'Input Validation Error: Invalid or missing UQC outcome %', (v_uqc_map->>'outcome');
        END IF;

        SELECT * INTO v_existing_uqc FROM catalog.uqc WHERE code = (v_uqc_map->>'uqc_code');
        IF (v_uqc_map->>'outcome') = 'MAPPED' THEN
            IF COALESCE(v_uqc_map->>'target_canonical_code', '') = '' THEN
                RAISE EXCEPTION 'MAPPED entry missing target_canonical_code for %', (v_uqc_map->>'uqc_code');
            END IF;
            SELECT id INTO v_unit_id FROM catalog.measurement_units WHERE canonical_code = (v_uqc_map->>'target_canonical_code');
            IF NOT FOUND THEN
                RAISE EXCEPTION 'Target canonical code not found: %', (v_uqc_map->>'target_canonical_code');
            END IF;
            
            IF v_existing_uqc.code IS NOT NULL THEN
                IF v_existing_uqc.measurement_unit_id IS NULL THEN
                    UPDATE catalog.uqc SET measurement_unit_id = v_unit_id WHERE id = v_existing_uqc.id;
                    v_uqc_mapped := v_uqc_mapped + 1;
                ELSIF v_existing_uqc.measurement_unit_id = v_unit_id THEN
                    v_uqc_unchanged := v_uqc_unchanged + 1;
                ELSE
                    RAISE EXCEPTION 'Unreviewed Overwrite Conflict: UQC % already mapped to a different unit', (v_uqc_map->>'uqc_code');
                END IF;
            ELSE
                INSERT INTO catalog.uqc (code, description, measurement_unit_id) VALUES (v_uqc_map->>'uqc_code', v_uqc_map->>'uqc_desc', v_unit_id);
                v_uqc_mapped := v_uqc_mapped + 1;
            END IF;
        ELSE
            IF v_existing_uqc.code IS NULL THEN
                INSERT INTO catalog.uqc (code, description) VALUES (v_uqc_map->>'uqc_code', v_uqc_map->>'uqc_desc');
            END IF;
            v_uqc_unmapped := v_uqc_unmapped + 1;
        END IF;
    END LOOP;

    RETURN jsonb_build_object('success', true, 'units_inserted', v_units_inserted, 'units_unchanged', v_units_unchanged, 'uqc_mapped', v_uqc_mapped, 'uqc_unchanged', v_uqc_unchanged, 'uqc_unmapped_or_ambiguous', v_uqc_unmapped, 'conv_inserted', v_conv_inserted, 'conv_unchanged', v_conv_unchanged);
END;
$$;

REVOKE EXECUTE ON FUNCTION catalog.import_unit_master_impl(JSONB, JSONB, JSONB) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.import_unit_master(p_units JSONB, p_uqc_mappings JSONB, p_conversions JSONB) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$ BEGIN RETURN catalog.import_unit_master_impl(p_units, p_uqc_mappings, p_conversions); END; $$;

REVOKE EXECUTE ON FUNCTION public.import_unit_master(JSONB, JSONB, JSONB) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.import_unit_master(JSONB, JSONB, JSONB) TO service_role;

-- Verify Assertions
DO $$
BEGIN
    IF has_table_privilege('anon', 'public.measurement_units', 'SELECT') OR has_table_privilege('authenticated', 'public.measurement_units', 'SELECT') OR has_table_privilege('anon', 'public.unit_conversions', 'SELECT') OR has_table_privilege('authenticated', 'public.unit_conversions', 'SELECT') THEN
        RAISE EXCEPTION 'Views incorrectly exposed to anon/authenticated';
    END IF;

    IF NOT has_table_privilege('service_role', 'public.measurement_units', 'SELECT') OR NOT has_table_privilege('service_role', 'public.unit_conversions', 'SELECT') THEN
        RAISE EXCEPTION 'service_role lacks SELECT on new views';
    END IF;

    IF has_table_privilege('service_role', 'public.measurement_units', 'INSERT') OR has_table_privilege('service_role', 'public.measurement_units', 'UPDATE') OR has_table_privilege('service_role', 'public.measurement_units', 'DELETE') THEN
        RAISE EXCEPTION 'service_role incorrectly granted write access on public.measurement_units';
    END IF;

    IF has_table_privilege('service_role', 'public.unit_conversions', 'INSERT') OR has_table_privilege('service_role', 'public.unit_conversions', 'UPDATE') OR has_table_privilege('service_role', 'public.unit_conversions', 'DELETE') THEN
        RAISE EXCEPTION 'service_role incorrectly granted write access on public.unit_conversions';
    END IF;
END $$;

NOTIFY pgrst, 'reload schema';
COMMIT;
