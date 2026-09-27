
CREATE TABLE catalog.jurisdictions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE catalog.jurisdictions ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog.jurisdictions FORCE ROW LEVEL SECURITY;

CREATE TABLE catalog.tax_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    jurisdiction_id UUID NOT NULL REFERENCES catalog.jurisdictions(id),
    code TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE catalog.tax_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog.tax_codes FORCE ROW LEVEL SECURITY;

CREATE TABLE catalog.tax_rates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tax_code_id UUID NOT NULL REFERENCES catalog.tax_codes(id),
    rate NUMERIC NOT NULL,
    effective_from TIMESTAMPTZ NOT NULL,
    effective_to TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE catalog.tax_rates ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog.tax_rates FORCE ROW LEVEL SECURITY;

CREATE TABLE catalog.hsn_sac (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT UNIQUE NOT NULL,
    description TEXT,
    type TEXT CHECK (type IN ('HSN', 'SAC')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE catalog.hsn_sac ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog.hsn_sac FORCE ROW LEVEL SECURITY;

CREATE TABLE catalog.uqc (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE catalog.uqc ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog.uqc FORCE ROW LEVEL SECURITY;

CREATE TABLE catalog.currencies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    symbol TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE catalog.currencies ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog.currencies FORCE ROW LEVEL SECURITY;

CREATE TABLE catalog.geo_masters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type TEXT NOT NULL,
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    parent_id UUID REFERENCES catalog.geo_masters(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE catalog.geo_masters ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog.geo_masters FORCE ROW LEVEL SECURITY;

CREATE TABLE catalog.catalog_releases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    version TEXT UNIQUE NOT NULL,
    status TEXT NOT NULL DEFAULT 'DRAFT',
    published_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE catalog.catalog_releases ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog.catalog_releases FORCE ROW LEVEL SECURITY;

CREATE TABLE catalog.catalog_release_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    release_id UUID NOT NULL REFERENCES catalog.catalog_releases(id),
    item_type TEXT NOT NULL,
    item_id UUID NOT NULL,
    payload JSONB NOT NULL
);
ALTER TABLE catalog.catalog_release_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog.catalog_release_items FORCE ROW LEVEL SECURITY;
