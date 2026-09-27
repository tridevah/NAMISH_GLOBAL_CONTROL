BEGIN;

INSERT INTO data_imports.release_execution_artifacts (release_id, artifact_type, artifact_payload)
VALUES (
    'b3573f9b-1eff-47d5-8cdf-fba3eba74b19',
    'R12_V3_EXTRACTOR_AUTHORIZATION',
    jsonb_build_object(
        'v3_hash', 'D3101E473754907D0AEB81B4D22954A44C152794D7523D28B2375895141AD575',
        'supplement_hash', 'BBC16582709A88EE808C1D7DBCA322E775ABE6836AF7ADA837BC8E8FC4C97DAC',
        'semantic_diff', 'Removed checkpoint check in Phase 1 to process PENDING DB state correctly for GRAM_PANCHAYAT.',
        'workset_size', 36,
        'targetless_on_conflict_count', 0,
        'pre_launch_tests_verified', true
    )
);

COMMIT;

