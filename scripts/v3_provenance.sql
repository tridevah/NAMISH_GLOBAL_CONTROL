BEGIN;

INSERT INTO data_imports.release_execution_artifacts (release_id, artifact_type, artifact_payload)
VALUES (
    'b3573f9b-1eff-47d5-8cdf-fba3eba74b19',
    'R12_V3_EXTRACTOR_AUTHORIZATION',
    jsonb_build_object(
        'v3_hash', '6883CA1D3AE4D55B2245700B03281578E0172BF9DFAC3DBA8D73721ACBA037DA',
        'supplement_hash', 'BBC16582709A88EE808C1D7DBCA322E775ABE6836AF7ADA837BC8E8FC4C97DAC',
        'semantic_diff', '1. Fixed strict inequality PRI_GRAM_PANCHAYAT vs GRAM_PANCHAYAT. 2. Fixed POST_OFFICE!0 to POST_OFFICE!1 index. 3. Added handlers for PIN_VILLAGE and PIN_URBAN_LOCAL_BODY based on supplemented keys. 4. Restricted execution exclusively to PENDING batches using explicit DB state selection. 5. Explicitly assign OFFICIAL_EMPTY only when actual physical data-row count is exactly zero.',
        'workset_size', 40,
        'targetless_on_conflict_count', 0,
        'pre_launch_tests_verified', true
    )
);

COMMIT;

