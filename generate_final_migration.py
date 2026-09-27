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

-- 1. Add schema columns
ALTER TABLE catalog.measurement_units
ADD COLUMN IF NOT EXISTS business_name TEXT,
ADD COLUMN IF NOT EXISTS short_name TEXT,
ADD COLUMN IF NOT EXISTS is_business BOOLEAN DEFAULT false;

-- 2. CREATE NAMISH-OWNED ENTRIES FOR MISSING PACKAGING UNITS
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

-- 3. APPLY METADATA AND MERGE ALIASES
"""

for code, bname, sname in metadata:
    if bname == "KILOGRAMS":
        sql += f"UPDATE catalog.measurement_units SET business_name = '{bname}', short_name = '{sname}', is_business = true, aliases = ARRAY(SELECT DISTINCT unnest(array_cat(aliases, ARRAY['KGS']))) WHERE canonical_code = '{code}';\n"
    else:
        sql += f"UPDATE catalog.measurement_units SET business_name = '{bname}', short_name = '{sname}', is_business = true WHERE canonical_code = '{code}';\n"

sql += """
-- 4. Recreate the public view
CREATE OR REPLACE VIEW public.measurement_units AS SELECT * FROM catalog.measurement_units;

-- 5. Preserve SELECT-only public-view permissions and read-only roles, but allow mutations for service_role
GRANT SELECT ON public.measurement_units TO authenticated, anon;
GRANT SELECT, INSERT, UPDATE ON public.measurement_units TO service_role;
GRANT SELECT, INSERT, UPDATE ON catalog.measurement_units TO service_role;

-- 6. ASSERTIONS: Verify exact 30 records are mapped correctly and no duplicates/conflicts exist
DO $$
DECLARE
    business_count INT;
BEGIN
    SELECT COUNT(*) INTO business_count FROM catalog.measurement_units WHERE is_business = true;
    IF business_count != 30 THEN
        RAISE EXCEPTION 'Assertion failed: Expected exactly 30 business units, found %', business_count;
    END IF;
    
    -- Validate NAMISH entries match standard
    IF NOT EXISTS (SELECT 1 FROM catalog.measurement_units WHERE canonical_code = 'NAMISH_BG' AND business_name = 'BAGS' AND short_name = 'Bag') THEN
        RAISE EXCEPTION 'Assertion failed: NAMISH_BG incorrectly defined or missing';
    END IF;
END $$;

COMMIT;
"""

with open("supabase/migrations/rehearsal_000036_units_metadata.sql", "w") as f:
    f.write(sql)

print("Created migration rehearsal_000036_units_metadata.sql")
