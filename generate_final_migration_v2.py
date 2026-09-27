import json

metadata = [
    ("NAMISH_BG", "BAGS", "Bag"),
    ("NAMISH_BO", "BOTTLES", "Btl"),
    ("NAMISH_BX", "BOX", "Box"),
    ("NAMISH_BE", "BUNDLES", "Bdl"),
    ("NAMISH_CA", "CANS", "Can"),
    ("NAMISH_CT", "CARTONS", "Ctn"),
    ("UNECE_REC20_MTQ", "CUBIC METER", "Cbm"),
    ("UNECE_REC20_DAY", "DAY", "Day"),
    ("UNECE_REC20_DZN", "DOZENS", "Dzn"),
    ("UNECE_REC20_GRM", "GRAMMES", "Gm"),
    ("UNECE_REC20_MGM", "MILLIGRAM", "mg"),
    ("UNECE_REC20_HUR", "HOUR", "Hr"),
    ("UNECE_REC20_KGM", "KILOGRAMS", "Kg"),
    ("UNECE_REC20_KMT", "KILOMETER", "Km"),
    ("UNECE_REC20_LTR", "LITRE", "Ltr"),
    ("UNECE_REC20_MTR", "METERS", "Mtr"),
    ("UNECE_REC20_MLT", "MILLILITRE", "Ml"),
    ("UNECE_REC20_C62", "NUMBERS", "Nos"),
    ("NAMISH_PK", "PACKS", "Pac"),
    ("UNECE_REC20_PR", "PAIRS", "Prs"),
    ("UNECE_REC20_H87", "PIECES", "Pcs"),
    ("UNECE_REC20_DTN", "QUINTAL", "Qtl"),
    ("NAMISH_RO", "ROLLS", "Rol"),
    ("UNECE_REC20_E48", "SERVICE", "Ser"),
    ("UNECE_REC20_SET", "SET", "Set"),
    ("UNECE_REC20_FTK", "SQUARE FEET", "Sqf"),
    ("UNECE_REC20_MTK", "SQUARE METERS", "Sqm"),
    ("UNECE_REC20_U2", "TABLETS", "Tbs"),
    ("UNECE_REC20_TNE", "TON / METRIC TON", "Ton"),
    ("UNECE_REC20_EA", "UNIT", "Unit")
]

sql = """BEGIN;

ALTER TABLE catalog.measurement_units
ADD COLUMN IF NOT EXISTS business_name TEXT,
ADD COLUMN IF NOT EXISTS short_name TEXT,
ADD COLUMN IF NOT EXISTS is_business BOOLEAN DEFAULT false;

INSERT INTO catalog.measurement_units (canonical_code, standard_code, name, category, status, source, source_version, aliases)
VALUES
('NAMISH_BG', 'BG', 'bag', 'Packaging', 'ACTIVE', 'NAMISH_INTERNAL', '1.0', '{}'),
('NAMISH_BO', 'BO', 'bottle', 'Packaging', 'ACTIVE', 'NAMISH_INTERNAL', '1.0', '{}'),
('NAMISH_BX', 'BX', 'box', 'Packaging', 'ACTIVE', 'NAMISH_INTERNAL', '1.0', '{}'),
('NAMISH_BE', 'BD', 'bundle', 'Packaging', 'ACTIVE', 'NAMISH_INTERNAL', '1.0', '{}'),
('NAMISH_CA', 'CA', 'can', 'Packaging', 'ACTIVE', 'NAMISH_INTERNAL', '1.0', '{}'),
('NAMISH_CT', 'CT', 'carton', 'Packaging', 'ACTIVE', 'NAMISH_INTERNAL', '1.0', '{}'),
('NAMISH_PK', 'PK', 'pack', 'Packaging', 'ACTIVE', 'NAMISH_INTERNAL', '1.0', '{}'),
('NAMISH_RO', 'RO', 'roll', 'Packaging', 'ACTIVE', 'NAMISH_INTERNAL', '1.0', '{}')
ON CONFLICT (canonical_code) DO NOTHING;

"""

for code, bname, sname in metadata:
    if bname == "KILOGRAMS":
        sql += f"UPDATE catalog.measurement_units SET business_name = '{bname}', short_name = '{sname}', is_business = true, aliases = ARRAY(SELECT DISTINCT unnest(array_cat(aliases, ARRAY['KGS']))) WHERE canonical_code = '{code}';\n"
    else:
        sql += f"UPDATE catalog.measurement_units SET business_name = '{bname}', short_name = '{sname}', is_business = true WHERE canonical_code = '{code}';\n"

sql += """
CREATE OR REPLACE VIEW public.measurement_units AS SELECT * FROM catalog.measurement_units;

REVOKE ALL ON public.measurement_units FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON public.measurement_units TO service_role;

CREATE OR REPLACE FUNCTION public.rpc_add_business_unit(
    p_business_name TEXT,
    p_short_name TEXT,
    p_aliases TEXT[],
    p_canonical_code TEXT,
    p_name TEXT
) RETURNS JSON AS $$
DECLARE
    new_code TEXT;
    res JSON;
BEGIN
    new_code := COALESCE(p_canonical_code, 'NAMISH_' || UPPER(p_short_name));
    
    INSERT INTO catalog.measurement_units (
        canonical_code, standard_code, name, category, status, source, source_version, business_name, short_name, is_business, aliases
    )
    VALUES (
        new_code, SUBSTRING(UPPER(p_short_name) FROM 1 FOR 3), COALESCE(p_name, LOWER(p_business_name)), 'Business', 'ACTIVE', 'NAMISH_INTERNAL', '1.0', p_business_name, p_short_name, true, COALESCE(p_aliases, '{}')
    )
    RETURNING row_to_json(measurement_units.*) INTO res;
    
    RETURN res;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = catalog, public;

CREATE OR REPLACE FUNCTION public.rpc_update_business_unit(
    p_id UUID,
    p_business_name TEXT,
    p_short_name TEXT,
    p_aliases TEXT[],
    p_status TEXT,
    p_is_business BOOLEAN
) RETURNS JSON AS $$
DECLARE
    res JSON;
BEGIN
    UPDATE catalog.measurement_units
    SET 
        business_name = COALESCE(p_business_name, business_name),
        short_name = COALESCE(p_short_name, short_name),
        aliases = COALESCE(p_aliases, aliases),
        status = COALESCE(p_status, status),
        is_business = COALESCE(p_is_business, is_business)
    WHERE id = p_id
    RETURNING row_to_json(measurement_units.*) INTO res;
    
    RETURN res;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = catalog, public;

REVOKE ALL ON FUNCTION public.rpc_add_business_unit FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_add_business_unit TO service_role;

REVOKE ALL ON FUNCTION public.rpc_update_business_unit FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_update_business_unit TO service_role;

DO $$
DECLARE
    c TEXT;
    expected_codes TEXT[] := ARRAY[
        'NAMISH_BG', 'NAMISH_BO', 'NAMISH_BX', 'NAMISH_BE', 
        'NAMISH_CA', 'NAMISH_CT', 'UNECE_REC20_MTQ', 'UNECE_REC20_DAY', 
        'UNECE_REC20_DZN', 'UNECE_REC20_GRM', 'UNECE_REC20_MGM', 'UNECE_REC20_HUR', 
        'UNECE_REC20_KGM', 'UNECE_REC20_KMT', 'UNECE_REC20_LTR', 'UNECE_REC20_MTR', 
        'UNECE_REC20_MLT', 'UNECE_REC20_C62', 'NAMISH_PK', 'UNECE_REC20_PR', 
        'UNECE_REC20_H87', 'UNECE_REC20_DTN', 'NAMISH_RO', 'UNECE_REC20_E48', 
        'UNECE_REC20_SET', 'UNECE_REC20_FTK', 'UNECE_REC20_MTK', 'UNECE_REC20_U2', 
        'UNECE_REC20_TNE', 'UNECE_REC20_EA'
    ];
BEGIN
    FOREACH c IN ARRAY expected_codes LOOP
        IF NOT EXISTS (SELECT 1 FROM catalog.measurement_units WHERE canonical_code = c AND is_business = true) THEN
            RAISE EXCEPTION 'Assertion failed: Expected business unit % is missing or not marked as business unit', c;
        END IF;
    END LOOP;

    IF EXISTS (
        SELECT 1 FROM catalog.measurement_units 
        WHERE canonical_code LIKE 'NAMISH_%' 
        AND source != 'NAMISH_INTERNAL'
    ) THEN
        RAISE EXCEPTION 'Assertion failed: NAMISH packaging identity conflict (wrong source)';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM catalog.measurement_units WHERE canonical_code = 'NAMISH_BG' AND business_name = 'BAGS' AND short_name = 'Bag') THEN
        RAISE EXCEPTION 'Assertion failed: NAMISH_BG definition conflict';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM catalog.measurement_units WHERE canonical_code = 'NAMISH_BO' AND business_name = 'BOTTLES' AND short_name = 'Btl') THEN
        RAISE EXCEPTION 'Assertion failed: NAMISH_BO definition conflict';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM catalog.measurement_units WHERE canonical_code = 'NAMISH_BX' AND business_name = 'BOX' AND short_name = 'Box') THEN
        RAISE EXCEPTION 'Assertion failed: NAMISH_BX definition conflict';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM catalog.measurement_units WHERE canonical_code = 'NAMISH_BE' AND business_name = 'BUNDLES' AND short_name = 'Bdl') THEN
        RAISE EXCEPTION 'Assertion failed: NAMISH_BE definition conflict';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM catalog.measurement_units WHERE canonical_code = 'NAMISH_CA' AND business_name = 'CANS' AND short_name = 'Can') THEN
        RAISE EXCEPTION 'Assertion failed: NAMISH_CA definition conflict';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM catalog.measurement_units WHERE canonical_code = 'NAMISH_CT' AND business_name = 'CARTONS' AND short_name = 'Ctn') THEN
        RAISE EXCEPTION 'Assertion failed: NAMISH_CT definition conflict';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM catalog.measurement_units WHERE canonical_code = 'NAMISH_PK' AND business_name = 'PACKS' AND short_name = 'Pac') THEN
        RAISE EXCEPTION 'Assertion failed: NAMISH_PK definition conflict';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM catalog.measurement_units WHERE canonical_code = 'NAMISH_RO' AND business_name = 'ROLLS' AND short_name = 'Rol') THEN
        RAISE EXCEPTION 'Assertion failed: NAMISH_RO definition conflict';
    END IF;
END $$;

COMMIT;
"""

with open("supabase/migrations/rehearsal_000036_units_metadata.sql", "w") as f:
    f.write(sql)
