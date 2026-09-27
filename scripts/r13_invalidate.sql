BEGIN;
INSERT INTO data_imports.release_execution_artifacts (release_id, artifact_type, artifact_payload)
VALUES (
    'b1300000-0000-0000-0000-000000000000',
    'INVALIDATED_OBSERVATION_IDENTITY_AND_STATUS_SEMANTICS',
    jsonb_build_object(
        'staged_rows_preserved', 751177,
        'incorrect_uuid_formula', 'Missing physical_row_number and full accurate tuple in v5 hash',
        'mutation_risk', 'ON CONFLICT DO UPDATE allowed overwriting existing raw data',
        'five_empty_batches_failed', 'Empty traditional local body batches marked FAILED instead of OFFICIAL_EMPTY',
        'conflicting_reports', 'Reported 3702 staged but actually 751177',
        'canonical_writes', 0
    )
);

UPDATE data_imports.releases SET status = 'INVALIDATED' WHERE id = 'b1300000-0000-0000-0000-000000000000';

COMMIT;
