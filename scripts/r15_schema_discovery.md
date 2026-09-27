EXISTING_BLOCK_PARENT_MODEL
The existing model relies on a strict 1-to-N scalar constraint. The catalog.development_blocks table contains a scalar district_id column representing a single parent district per block.

EXISTING_MULTI_DISTRICT_SUPPORT
FALSE. The database currently lacks support for multi-district blocks. Attempting to stage the 15 bifurcated blocks into the canonical tables would result in a conflict on the development_blocks_official_code_key UNIQUE constraint if duplicated, or silent data loss if upserted ("latest row wins").

EXISTING_RELATIONSHIP_TABLES
None for Block-to-District relationships. Bridging tables only exist downwards (e.g., catalog.block_villages).

UNIQUE_CONSTRAINTS
- development_blocks_official_code_key UNIQUE (official_code) on catalog.development_blocks.
- development_blocks_pkey PRIMARY KEY (id).

API_AND_UI_COMPATIBILITY
The API layer relies on pc_get_development_blocks(), which returns SETOF catalog.development_blocks. If district_id is removed from the table, the API payload will automatically change. However, a codebase audit (Select-String "development_blocks") shows zero active UI consumers strictly depending on the current district_id scalar, making it perfectly safe to refactor the API boundary at this phase.

MINIMAL_FORWARD_MIGRATION_REQUIRED
`sql
-- 20260830000034_multi_district_blocks.sql
BEGIN;

-- 1. Create junction table
CREATE TABLE catalog.block_districts (
    block_id pg_catalog.uuid NOT NULL REFERENCES catalog.development_blocks(id) ON DELETE CASCADE,
    district_id pg_catalog.uuid NOT NULL REFERENCES catalog.geography_units(id) ON DELETE CASCADE,
    PRIMARY KEY (block_id, district_id)
);
ALTER TABLE catalog.block_districts ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog.block_districts FORCE ROW LEVEL SECURITY;

-- 2. Migrate existing references (Safe: 0 canonical blocks exist)
INSERT INTO catalog.block_districts (block_id, district_id)
SELECT id, district_id FROM catalog.development_blocks WHERE district_id IS NOT NULL;

-- 3. Drop scalar constraint
ALTER TABLE catalog.development_blocks DROP COLUMN district_id;

-- (The RPC rpc_get_development_blocks will implicitly update its return type since it relies on SETOF catalog.development_blocks)
COMMIT;
`

R15_SOURCE_SNAPSHOT_TIMESTAMPS
- Started At: 2026-08-30 08:06:20.437083+00
- Completed At: 2026-08-30 08:13:20.775166+00

CANONICAL_BLOCK_COUNT = 7323
BLOCK_DISTRICT_RELATIONSHIP_COUNT = 7338
DATABASE_FILE_CHANGE_COUNT = 0
PHASE_B_GATE_RESULT = BLOCKED_MULTI_PARENT_SCHEMA_REQUIRED
NEXT_SAFE_ACTION = APPLY_FORWARD_MIGRATION
