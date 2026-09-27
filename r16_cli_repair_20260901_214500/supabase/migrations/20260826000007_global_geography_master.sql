-- Migration 000008: Global Geography Master
-- Enforces strict hierarchical global geography constraints.

-- 1. Country Authority Enhancements
CREATE TABLE catalog.countries (
    id pg_catalog.uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    iso2 TEXT NOT NULL,
    iso3 TEXT NOT NULL,
    numeric_code TEXT,
    official_name TEXT NOT NULL,
    display_name TEXT NOT NULL,
    default_currency_code TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'ACTIVE',
    effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    effective_to TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by pg_catalog.uuid REFERENCES platform.platform_staff(id),
    updated_by pg_catalog.uuid REFERENCES platform.platform_staff(id)
);
ALTER TABLE catalog.countries ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog.countries FORCE ROW LEVEL SECURITY;

ALTER TABLE catalog.countries ADD CONSTRAINT countries_effective_dates_check CHECK (effective_to IS NULL OR effective_to >= effective_from);
ALTER TABLE catalog.countries ADD CONSTRAINT countries_status_check CHECK (status IN ('ACTIVE', 'INACTIVE'));

CREATE UNIQUE INDEX countries_iso2_idx ON catalog.countries (UPPER(iso2));
CREATE UNIQUE INDEX countries_iso3_idx ON catalog.countries (UPPER(iso3));

-- 2. Geography Levels
CREATE TABLE catalog.geography_levels (
    id pg_catalog.uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    country_id pg_catalog.uuid NOT NULL REFERENCES catalog.countries(id),
    level_number INT NOT NULL CHECK (level_number > 0),
    level_key TEXT NOT NULL,
    display_label TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE')),
    effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    effective_to TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by pg_catalog.uuid REFERENCES platform.platform_staff(id),
    updated_by pg_catalog.uuid REFERENCES platform.platform_staff(id),
    UNIQUE (country_id, level_number),
    UNIQUE (country_id, level_key),
    UNIQUE (id, country_id), -- Required for composite foreign key targeting
    CHECK (effective_to IS NULL OR effective_to >= effective_from)
);
ALTER TABLE catalog.geography_levels ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog.geography_levels FORCE ROW LEVEL SECURITY;

-- 3. Geography Units
CREATE TABLE catalog.geography_units (
    id pg_catalog.uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    country_id pg_catalog.uuid NOT NULL REFERENCES catalog.countries(id),
    geography_level_id pg_catalog.uuid NOT NULL,
    parent_geography_unit_id pg_catalog.uuid,
    official_code TEXT NOT NULL,
    iso_subdivision_code TEXT,
    official_name TEXT NOT NULL,
    display_name TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE')),
    effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    effective_to TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by pg_catalog.uuid REFERENCES platform.platform_staff(id),
    updated_by pg_catalog.uuid REFERENCES platform.platform_staff(id),
    FOREIGN KEY (geography_level_id, country_id) REFERENCES catalog.geography_levels(id, country_id),
    FOREIGN KEY (parent_geography_unit_id, country_id) REFERENCES catalog.geography_units(id, country_id),
    UNIQUE (id, country_id),
    UNIQUE (country_id, geography_level_id, official_code),
    UNIQUE (country_id, iso_subdivision_code),
    CHECK (effective_to IS NULL OR effective_to >= effective_from)
);
ALTER TABLE catalog.geography_units ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog.geography_units FORCE ROW LEVEL SECURITY;

CREATE UNIQUE INDEX geo_units_normalized_name_idx ON catalog.geography_units (
    country_id, 
    geography_level_id, 
    COALESCE(parent_geography_unit_id, '00000000-0000-0000-0000-000000000000'::uuid), 
    UPPER(official_name)
);

-- Trigger to validate hierarchy constraint (Parent must be n-1 level)
CREATE OR REPLACE FUNCTION catalog.validate_geography_unit_parent()
RETURNS pg_catalog.trigger AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path TO pg_catalog;

CREATE TRIGGER validate_geography_unit_parent_trigger
BEFORE INSERT OR UPDATE ON catalog.geography_units
FOR EACH ROW EXECUTE FUNCTION catalog.validate_geography_unit_parent();

-- 4. Postal Codes
CREATE TABLE catalog.postal_codes (
    id pg_catalog.uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    country_id pg_catalog.uuid NOT NULL REFERENCES catalog.countries(id),
    postal_code TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE')),
    effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    effective_to TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by pg_catalog.uuid REFERENCES platform.platform_staff(id),
    updated_by pg_catalog.uuid REFERENCES platform.platform_staff(id),
    UNIQUE (id, country_id),
    UNIQUE (country_id, postal_code),
    CHECK (effective_to IS NULL OR effective_to >= effective_from)
);
ALTER TABLE catalog.postal_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog.postal_codes FORCE ROW LEVEL SECURITY;

-- 5. Postal Code Geographies Mapping
CREATE TABLE catalog.postal_code_geographies (
    postal_code_id pg_catalog.uuid NOT NULL,
    geography_unit_id pg_catalog.uuid NOT NULL,
    country_id pg_catalog.uuid NOT NULL,
    PRIMARY KEY (postal_code_id, geography_unit_id),
    FOREIGN KEY (postal_code_id, country_id) REFERENCES catalog.postal_codes(id, country_id),
    FOREIGN KEY (geography_unit_id, country_id) REFERENCES catalog.geography_units(id, country_id)
);
ALTER TABLE catalog.postal_code_geographies ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog.postal_code_geographies FORCE ROW LEVEL SECURITY;

