-- 000021_batches_reconciliation_columns.sql
-- Add reconciliation columns to data_imports.batches that the physical importer requires.
-- These are additive — no existing column is modified.

ALTER TABLE data_imports.batches
    ADD COLUMN IF NOT EXISTS staged_rows      INTEGER DEFAULT 0,
    ADD COLUMN IF NOT EXISTS inserted_rows    INTEGER DEFAULT 0,
    ADD COLUMN IF NOT EXISTS updated_rows     INTEGER DEFAULT 0,
    ADD COLUMN IF NOT EXISTS unchanged_rows   INTEGER DEFAULT 0,
    ADD COLUMN IF NOT EXISTS rejected_rows    INTEGER DEFAULT 0,
    ADD COLUMN IF NOT EXISTS source_path      TEXT,
    ADD COLUMN IF NOT EXISTS importer_version TEXT;

-- Purge all staging rows for R6 (aborted partial run — no checkpoint was completed)
DELETE FROM staging.geography_imports
WHERE batch_id IN (
    SELECT b.id FROM data_imports.batches b
    JOIN data_imports.releases r ON r.id = b.release_id
    WHERE r.release_name = 'LGD_20260826_CORE_R6'
);

-- Reset all R6 batches to PENDING (clean slate for re-run)
UPDATE data_imports.batches SET status = 'PENDING',
    staged_rows=0, inserted_rows=0, updated_rows=0, unchanged_rows=0, rejected_rows=0,
    started_at=NULL, completed_at=NULL
WHERE release_id = (SELECT id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R6');
