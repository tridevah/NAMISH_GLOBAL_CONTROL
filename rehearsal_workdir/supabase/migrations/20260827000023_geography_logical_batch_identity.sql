-- 000023_geography_logical_batch_identity.sql

-- Drop the flawed constraint
ALTER TABLE data_imports.batches DROP CONSTRAINT IF EXISTS batches_release_id_entity_type_key;

-- Add logical batch mapping columns
ALTER TABLE data_imports.batches
ADD COLUMN IF NOT EXISTS manifest_logical_output_id UUID REFERENCES data_imports.release_manifest_logical_outputs(id),
ADD COLUMN IF NOT EXISTS logical_batch_key TEXT;

-- For existing R1-R7 data, logical_batch_key can remain NULL, but we need to ensure they don't break.
-- The prompt states: "Legacy releases may retain NULL linkage. R8 registration must reject NULL logical_batch_key."
-- We can add a CHECK constraint, or rely on R8 logic.
-- Canonical logical batch identity must be: UNIQUE (release_id, logical_batch_key)
CREATE UNIQUE INDEX IF NOT EXISTS batches_release_id_logical_batch_key_idx ON data_imports.batches(release_id, logical_batch_key) WHERE logical_batch_key IS NOT NULL;
