BEGIN;

INSERT INTO data_imports.release_execution_artifacts (release_id, artifact_type, artifact_payload)
VALUES (
    'b3573f9b-1eff-47d5-8cdf-fba3eba74b19',
    'INVALIDATED_DUPLICATE_OBSERVATIONS_AND_PRI_TIER_MISCLASSIFICATION',
    jsonb_build_object(
        'staged_rows_preserved', 13341820,
        'duplicated_observations', 6433627,
        'pri_tier_misclassification', 'Tier 3 Gram Panchayats were erroneously classified as PRI_INTERMEDIATE due to physical files universally using Tier Code 3, conflicting with LGD API global type codes',
        'invalid_v3_preflight', 'Preflight falsely asserted Codes 5/6 mapping without executing physical file read',
        'physical_manifest_duplication', 'Migration 000031 duplicated physical entries instead of injecting logical outputs',
        'rows_deleted', 0
    )
);

UPDATE data_imports.releases SET status = 'INVALIDATED' WHERE id = 'b3573f9b-1eff-47d5-8cdf-fba3eba74b19';

COMMIT;

