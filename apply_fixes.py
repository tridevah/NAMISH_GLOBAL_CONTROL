import re

# 1. Update SQL Migration
sql_path = 'supabase/migrations/rehearsal_000036_units_metadata.sql'
with open(sql_path, 'r', encoding='utf-8') as f:
    sql = f.read()

# Add unique index
unique_index_sql = """
-- ── 1a. ENFORCE BUSINESS UNIT UNIQUENESS ─────────────────────────────────────
CREATE UNIQUE INDEX IF NOT EXISTS uq_business_unit_identity
    ON catalog.measurement_units (LOWER(TRIM(business_name)), LOWER(TRIM(short_name)))
    WHERE is_business = true;
"""
sql = sql.replace('-- ── 2. SEED MISSING NAMISH-OWNED PACKAGING ENTRIES', unique_index_sql + '\n-- ── 2. SEED MISSING NAMISH-OWNED PACKAGING ENTRIES')

# Add computed function for alias search
computed_func_sql = """
-- ── 5a. COMPUTED FIELD FOR ALIAS SEARCH ──────────────────────────────────────
CREATE OR REPLACE FUNCTION public.aliases_text(u public.measurement_units)
RETURNS TEXT
LANGUAGE sql IMMUTABLE
AS $func$
  SELECT array_to_string(u.aliases, ' ');
$func$;
"""
sql = sql.replace('-- ── 6. RESTORE PERMISSIONS', computed_func_sql + '\n-- ── 6. RESTORE PERMISSIONS')

with open(sql_path, 'w', encoding='utf-8') as f:
    f.write(sql)

# 2. Update API Route
route_path = 'src/app/api/data-hub/units/route.ts'
with open(route_path, 'r', encoding='utf-8') as f:
    route = f.read()

# Replace aliases.cs with aliases_text.ilike
route = route.replace('aliases.cs.{${search}}', 'aliases_text.ilike.%${search}%')

with open(route_path, 'w', encoding='utf-8') as f:
    f.write(route)
