-- Operational Script: GC Catalog Sync Sequence Correction
-- File:      scripts/20260927_gc_sequence_correction.sql
-- Scope:     GC database
-- Purpose:   Guarded, forward-only sequence correction for catalog.release_seq.
--            Acquires publisher serialization lock (same as catalog.fn_publish_release)
--            to prevent concurrent modifications during correction.

BEGIN;
SET LOCAL search_path = '';

DO $$
DECLARE
    -- The DBA must verify the ERP high-water mark from integration.sync_receipts
    -- and set it here before execution.
    v_erp_high_water_mark BIGINT := :erp_high_water_mark; 
    v_target_seq BIGINT := v_erp_high_water_mark + 1;
    v_current_seq BIGINT;
    v_is_called BOOLEAN;
    v_outbox_max BIGINT;
    v_release_max BIGINT;
    v_new_val BIGINT;
    v_has_lock BOOLEAN;
BEGIN
    -- 1. Quiesce publishers by acquiring the serialization lock (Matches fn_publish_release exactly)
    SELECT EXISTS (
        SELECT 1 FROM catalog.catalog_sync_control WHERE contract_key = 'AGGREGATE_V1' FOR UPDATE NOWAIT
    ) INTO v_has_lock;
    
    IF NOT v_has_lock THEN
        RAISE EXCEPTION 'BLOCKED: Could not acquire publisher serialization lock or control row is absent.';
    END IF;

    -- 2. Inspect actual sequence state & calculate true high-water mark
    SELECT last_value, is_called INTO v_current_seq, v_is_called FROM catalog.release_seq;
    
    SELECT COALESCE(MAX(release_sequence), 0) INTO v_outbox_max FROM (
        SELECT (payload->>'release_sequence')::BIGINT AS release_sequence 
        FROM integration.outbox_events WHERE event_type = 'catalog.release.published'
    ) q;
    
    SELECT COALESCE(MAX(release_sequence), 0) INTO v_release_max FROM catalog.catalog_releases;

    v_new_val := GREATEST(v_target_seq, v_outbox_max + 1, v_release_max + 1);
    IF v_is_called THEN
        v_new_val := GREATEST(v_new_val, v_current_seq + 1);
    ELSE
        v_new_val := GREATEST(v_new_val, v_current_seq);
    END IF;

    -- 3. Apply correction forward-only
    IF (v_is_called AND v_current_seq < v_new_val - 1) OR (NOT v_is_called AND v_current_seq < v_new_val) THEN
        PERFORM pg_catalog.setval('catalog.release_seq', v_new_val - 1, true);
        RAISE NOTICE 'Advanced catalog.release_seq to yield % on next call (was last_value=%, is_called=%)', v_new_val, v_current_seq, v_is_called;
    ELSE
        RAISE NOTICE 'catalog.release_seq already safely ahead. Next call yields >= % (last_value=%, is_called=%)', v_new_val, v_current_seq, v_is_called;
    END IF;
END;
$$;
COMMIT;
