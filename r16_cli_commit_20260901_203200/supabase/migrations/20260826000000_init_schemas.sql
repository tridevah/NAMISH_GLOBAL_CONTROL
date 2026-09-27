
CREATE SCHEMA IF NOT EXISTS platform;
CREATE SCHEMA IF NOT EXISTS billing;
CREATE SCHEMA IF NOT EXISTS catalog;
CREATE SCHEMA IF NOT EXISTS integration;
CREATE SCHEMA IF NOT EXISTS audit;

-- Roles for application access control, wait, we use RLS with JWT claims
-- But the instructions say:
-- 4. Implement dedicated staff authentication and roles:
-- PLATFORM_SUPERADMIN, CATALOG_MANAGER, BILLING_MANAGER, SUPPORT_AUDITOR
