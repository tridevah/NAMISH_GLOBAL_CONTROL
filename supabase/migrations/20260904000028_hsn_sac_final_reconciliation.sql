-- Migration 20260904000028: Final HSN/SAC Reconciliation
-- 1. Correct the 7 normalization collisions with exact DGFT ITC(HS) 2022 descriptions.
-- 2. Move synthetic row 99 to data_imports.row_errors and delete from catalog.hsn_sac.

-- 1. HSN Collisions Resolution
UPDATE catalog.hsn_sac SET description = 'Wine lees; argol' WHERE code = '230700' AND code_type = 'HSN';
UPDATE catalog.hsn_sac SET description = 'Slate, whether or not roughly trimmed or merely cut, by sawing or otherwise, into blocks or slabs of a rectangular (including square) shape' WHERE code = '251400' AND code_type = 'HSN';
UPDATE catalog.hsn_sac SET description = 'Other :' WHERE code = '030559' AND code_type = 'HSN';
UPDATE catalog.hsn_sac SET description = 'Squid tubes' WHERE code = '03074330' AND code_type = 'HSN';
UPDATE catalog.hsn_sac SET description = 'In powder, granules or other solid forms, of a fat content, by weight not exceeding 1.5% :' WHERE code = '040210' AND code_type = 'HSN';
UPDATE catalog.hsn_sac SET description = 'Fish nails' WHERE code = '05119110' AND code_type = 'HSN';
UPDATE catalog.hsn_sac SET description = 'Not decaffeinated :' WHERE code = '090121' AND code_type = 'HSN';

-- 2. Move Synthetic Row 99 to data_imports.row_errors and delete it
DO $$
DECLARE
  v_id UUID := 'da886d36-6df4-482d-bd5b-76665e2b0a52'::UUID;
  v_release_id UUID := gen_random_uuid();
  v_batch_id UUID := gen_random_uuid();
  v_row_json JSONB;
BEGIN
  -- Get the full row state for preservation
  SELECT row_to_json(h)::jsonb INTO v_row_json
  FROM catalog.hsn_sac h
  WHERE id = v_id;

  IF FOUND THEN
    -- Create dummy release and batch to satisfy foreign keys
    INSERT INTO data_imports.releases (id, release_name, source_uri, sha256_hash, manifest_hash, status, started_at, completed_at)
    VALUES (v_release_id, 'HSN_Synthetic_Row_Eviction', 'internal://migration_000028', '0000000000000000000000000000000000000000000000000000000000000000', '0000000000000000000000000000000000000000000000000000000000000000', 'FINALIZED', NOW(), NOW());

    INSERT INTO data_imports.batches (id, release_id, logical_batch_key, entity_type, total_records, successful_records, failed_records, status, started_at, completed_at)
    VALUES (v_batch_id, v_release_id, 'hsn_eviction', 'BLOCK', 1, 0, 1, 'FINALIZED', NOW(), NOW());

    -- Insert into row_errors
    INSERT INTO data_imports.row_errors (id, batch_id, official_code, row_data, error_message, occurrence_count)
    VALUES (v_id, v_batch_id, '99', v_row_json, 'Synthetic HSN code 99 evicted from active catalog (not present in official GST/DGFT master)', 1);

    -- Delete from catalog.hsn_sac
    DELETE FROM catalog.hsn_sac WHERE id = v_id;
  END IF;
END $$;
