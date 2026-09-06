-- Migration 20260904000027: Correct extra HSN row + mark dataset ERP-exposable=false
--
-- AUDIT FINDINGS:
-- EXTRA ROW IDENTIFIED:
--   id:          da886d36-6df4-482d-bd5b-76665e2b0a52
--   code:        99
--   code_type:   HSN
--   description: Miscellaneous goods (Chapter 99)
--   status:      TOP_LEVEL_CLASSIFICATION_ONLY
--   origin:      20260904000004_gst_master_standalone.sql
--   HSN source:  HSN_SAC.xlsx SHA256:051108e31063f1ef0d6dfb005a622bcc848878fa2d94fae51a73e67f8916871e
--   Chapter 99 is a special provisions chapter, not a standard goods chapter in ITC(HS).
--   It is not included in the GST Portal Excel.
--
-- ACTION:
--   1. Expand check constraints to allow quarantine labels.
--   2. Reclassify the extra row (preserve UUID). Set code_type='HSN_SPECIAL', status='QUARANTINE_NOT_IN_SOURCE'.
--   3. Mark country_tax_coverage status='PENDING_VERIFICATION'.

ALTER TABLE catalog.hsn_sac DROP CONSTRAINT IF EXISTS hsn_sac_status_check;
ALTER TABLE catalog.hsn_sac ADD CONSTRAINT hsn_sac_status_check 
  CHECK (status = ANY (ARRAY['ACTIVE', 'INACTIVE', 'TOP_LEVEL_CLASSIFICATION_ONLY', 'QUARANTINE_NOT_IN_SOURCE']));

ALTER TABLE catalog.hsn_sac DROP CONSTRAINT IF EXISTS hsn_sac_code_type_check;
ALTER TABLE catalog.hsn_sac ADD CONSTRAINT hsn_sac_code_type_check 
  CHECK (code_type = ANY (ARRAY['HSN', 'SAC', 'HSN_SPECIAL']));

DO $$
DECLARE
  v_id UUID := 'da886d36-6df4-482d-bd5b-76665e2b0a52'::UUID;
  v_code TEXT;
  v_code_type TEXT;
BEGIN
  -- Verify the row matches exactly what we expect
  SELECT code, code_type
  INTO v_code, v_code_type
  FROM catalog.hsn_sac
  WHERE id = v_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'ASSERTION FAILED: Row id=% not found', v_id;
  END IF;

  IF v_code <> '99' THEN
    RAISE EXCEPTION 'ASSERTION FAILED: Expected code=99, got code=%', v_code;
  END IF;

  IF v_code_type <> 'HSN' THEN
    RAISE EXCEPTION 'ASSERTION FAILED: Expected code_type=HSN, got code_type=%', v_code_type;
  END IF;

  -- Reclassify
  UPDATE catalog.hsn_sac
  SET
    code_type = 'HSN_SPECIAL',
    status    = 'QUARANTINE_NOT_IN_SOURCE',
    source_reference = source_reference || ' | QUARANTINED: not in GST Portal HSN_MSTR Excel | origin: 000004'
  WHERE id = v_id;

END $$;

-- Mark dataset pending verification (UNRESOLVED)
UPDATE catalog.country_tax_coverage
SET status = 'UNRESOLVED',
    reason = 'GST Rates pending verification against latest notification'
WHERE country_id = (SELECT id FROM catalog.countries WHERE iso2 = 'IN');
