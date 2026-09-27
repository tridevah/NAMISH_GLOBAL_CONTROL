
CREATE TABLE platform.platform_staff (
    id UUID PRIMARY KEY REFERENCES auth.users(id),
    email TEXT UNIQUE NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('PLATFORM_SUPERADMIN', 'CATALOG_MANAGER', 'BILLING_MANAGER', 'SUPPORT_AUDITOR')),
    status TEXT NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE platform.platform_staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE platform.platform_staff FORCE ROW LEVEL SECURITY;

CREATE TABLE platform.platform_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE platform.platform_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE platform.platform_accounts FORCE ROW LEVEL SECURITY;

CREATE TABLE platform.account_owners (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    platform_account_id UUID NOT NULL REFERENCES platform.platform_accounts(id),
    email TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE platform.account_owners ENABLE ROW LEVEL SECURITY;
ALTER TABLE platform.account_owners FORCE ROW LEVEL SECURITY;

CREATE TABLE platform.tenant_registry (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    platform_account_id UUID NOT NULL REFERENCES platform.platform_accounts(id),
    erp_tenant_id UUID, -- Tied to the ERP database
    status TEXT NOT NULL DEFAULT 'PROVISIONING',
    created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE platform.tenant_registry ENABLE ROW LEVEL SECURITY;
ALTER TABLE platform.tenant_registry FORCE ROW LEVEL SECURITY;

CREATE TABLE platform.provisioning_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES platform.tenant_registry(id),
    status TEXT NOT NULL,
    logs JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE platform.provisioning_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE platform.provisioning_jobs FORCE ROW LEVEL SECURITY;
