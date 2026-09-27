BEGIN;

-- 1. Append the two missing manifest logical-output records
INSERT INTO data_imports.release_manifest_entries (release_id, path, size, source_sha256, entity_type, role, scope)
VALUES
('b3573f9b-1eff-47d5-8cdf-fba3eba74b19', 'Pincodeto_Village_Mapping_2026-08-26_23-05-48.xlsx!!PIN_VILLAGE!0', 31920865, 'a150e95899b43363c93031feac498e5422ff3c3ea6f7b6d6ab244bb50b5a1db5', 'PIN_VILLAGE', 'IMPORT_AUTHORITY', 'ALL_INDIA'),
('b3573f9b-1eff-47d5-8cdf-fba3eba74b19', 'Pincodeto_Urban_Mapping_2026-08-26_23-06-09.xlsx!!PIN_URBAN_LOCAL_BODY!0', 280422, '08a65a7ea9a5b388ea835f8e2422bd1353912a0a916be3ee0a939c0e57480a74', 'PIN_URBAN_LOCAL_BODY', 'IMPORT_AUTHORITY', 'ALL_INDIA');

-- 2. Register one PIN_VILLAGE batch and one PIN_URBAN_LOCAL_BODY batch
INSERT INTO data_imports.batches (release_id, source_path, entity_type, logical_batch_key, status)
VALUES
('b3573f9b-1eff-47d5-8cdf-fba3eba74b19', 'Pincodeto_Village_Mapping_2026-08-26_23-05-48.xlsx', 'PIN_VILLAGE', 'Pincodeto_Village_Mapping_2026-08-26_23-05-48.xlsx!!PIN_VILLAGE!0', 'PENDING'),
('b3573f9b-1eff-47d5-8cdf-fba3eba74b19', 'Pincodeto_Urban_Mapping_2026-08-26_23-06-09.xlsx', 'PIN_URBAN_LOCAL_BODY', 'Pincodeto_Urban_Mapping_2026-08-26_23-06-09.xlsx!!PIN_URBAN_LOCAL_BODY!0', 'PENDING');

-- 3. Transition all 36 GRAM_PANCHAYAT batches to PENDING
UPDATE data_imports.batches SET status = 'PENDING' WHERE release_id = 'b3573f9b-1eff-47d5-8cdf-fba3eba74b19' AND entity_type = 'GRAM_PANCHAYAT';

-- 4. Append immutable provenance event
INSERT INTO data_imports.release_execution_artifacts (release_id, artifact_type, artifact_payload)
VALUES (
    'b3573f9b-1eff-47d5-8cdf-fba3eba74b19',
    'R12_LOGICAL_OUTPUT_MATRIX_CORRECTION',
    jsonb_build_object(
        'base_manifest_hash', 'e67f03ced808ac3569e1de47a6310f2df11b472a6729dfb4822a3ad278fb4e9c',
        'supplement_hash', 'BBC16582709A88EE808C1D7DBCA322E775ABE6836AF7ADA837BC8E8FC4C97DAC',
        'missing_output_root_cause', 'PIN files were marked UNKNOWN in base manifest and never registered. GRAM_PANCHAYAT rows were skipped by extractor due to strict inequality PRI_GRAM_PANCHAYAT !== GRAM_PANCHAYAT',
        'gp_false_staged_statuses', 17,
        'gp_false_official_empty_statuses', 19,
        'newly_registered_pin_batches', 2,
        'previous_logical_batch_count', 506,
        'corrected_logical_batch_count', 508,
        'existing_staging_rows_preserved', 5897549,
        'canonical_writes', 0
    )
);

COMMIT;

