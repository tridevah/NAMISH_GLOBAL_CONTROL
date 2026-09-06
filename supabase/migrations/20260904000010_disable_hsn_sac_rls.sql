-- Migration 20260904000010: Disable RLS on catalog.hsn_sac
-- Catalog master data is protected by GRANT, not RLS.
ALTER TABLE catalog.hsn_sac DISABLE ROW LEVEL SECURITY;
