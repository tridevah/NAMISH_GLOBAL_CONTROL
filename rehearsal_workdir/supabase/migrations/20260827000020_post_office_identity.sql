-- 000020_post_office_identity.sql

-- 1. Invalidate R5
UPDATE data_imports.releases 
SET status='INVALIDATED', invalidated_reason='INVALIDATED_POST_OFFICE_IDENTITY_COLLISION', invalidated_at=NOW() 
WHERE release_name='LGD_20260826_CORE_R5';

-- 2. Post Office Canonical Identity
CREATE TABLE IF NOT EXISTS catalog.post_offices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    official_office_id TEXT UNIQUE, -- e.g. from Locate Post Office bulk export (NULL when unavailable)
    postal_code_id UUID, -- Will link to catalog.pincodes later
    pincode TEXT NOT NULL,
    office_name TEXT NOT NULL,
    office_type TEXT NOT NULL,
    delivery_status TEXT,
    status TEXT DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Versioned Source Identities
CREATE TABLE IF NOT EXISTS catalog.post_office_source_identities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_office_id UUID NOT NULL REFERENCES catalog.post_offices(id),
    source_authority TEXT NOT NULL, -- e.g. 'INDIA_POST_LGD'
    identity_version TEXT NOT NULL, -- e.g. 'DOP_PIN_CSV_V1'
    identity_key TEXT NOT NULL,     -- The generated canonical hash/string
    identity_basis JSONB NOT NULL,  -- The raw components used
    status TEXT DEFAULT 'CURRENT',
    UNIQUE(source_authority, identity_version, identity_key)
);

CREATE TABLE IF NOT EXISTS catalog.post_office_source_observations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_identity_id UUID NOT NULL REFERENCES catalog.post_office_source_identities(id),
    release_id UUID NOT NULL REFERENCES data_imports.releases(id),
    source_file_sha256 TEXT NOT NULL,
    physical_row_number BIGINT,
    raw_data JSONB,
    observed_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(release_id, source_file_sha256, physical_row_number)
);

CREATE TABLE IF NOT EXISTS catalog.post_office_identity_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    release_id UUID NOT NULL REFERENCES data_imports.releases(id),
    identity_version TEXT NOT NULL,
    identity_key TEXT NOT NULL,
    conflicting_row_data JSONB NOT NULL,
    reason TEXT NOT NULL,
    status TEXT DEFAULT 'PENDING_REVIEW',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Create R6 Release
INSERT INTO data_imports.releases (release_name, source_uri, sha256_hash, status)
VALUES ('LGD_20260826_CORE_R6', 'local_dir', 'r6_manifest_pending', 'IN_PROGRESS')
ON CONFLICT(release_name) DO NOTHING;
