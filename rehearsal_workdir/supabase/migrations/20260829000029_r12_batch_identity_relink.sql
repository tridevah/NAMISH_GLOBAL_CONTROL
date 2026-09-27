BEGIN;

CREATE TABLE IF NOT EXISTS data_imports.release_execution_artifacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    release_id UUID NOT NULL REFERENCES data_imports.releases(id),
    artifact_type TEXT NOT NULL,
    artifact_payload JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

DO $code$
DECLARE
    affected_rows INTEGER;
BEGIN
    WITH map AS (
        SELECT id as correct_batch_id, entity_type,
               CASE
                   WHEN entity_type IN ('PINCODE', 'POST_OFFICE') THEN 'PIN CODE.csv'
                   WHEN entity_type = 'PIN_VILLAGE' THEN 'Pincodeto_Village_Mapping.xlsx'
                   WHEN entity_type = 'PIN_URBAN_LOCAL_BODY' THEN 'Pincodeto_Urban_Mapping.xlsx'
                   ELSE SUBSTRING(logical_batch_key FROM '^(.*)!' || entity_type || '![0-9]+$')
               END as internal_member_or_sheet
        FROM data_imports.batches
        WHERE release_id = 'b3573f9b-1eff-47d5-8cdf-fba3eba74b19'
    )
    UPDATE staging.geography_imports s
    SET batch_id = map.correct_batch_id
    FROM map
    WHERE s.release_id = 'b3573f9b-1eff-47d5-8cdf-fba3eba74b19'
      AND s.entity_type = map.entity_type
      AND s.internal_member_or_sheet = map.internal_member_or_sheet
      AND s.batch_id != map.correct_batch_id;
      
    GET DIAGNOSTICS affected_rows = ROW_COUNT;
    
    INSERT INTO data_imports.release_execution_artifacts (release_id, artifact_type, artifact_payload)
    VALUES (
        'b3573f9b-1eff-47d5-8cdf-fba3eba74b19',
        'BATCH_IDENTITY_RELINK',
        jsonb_build_object(
            'rows_relinked', affected_rows,
            'initial_importer_hash', '311b1c99c768a6bc72b18084ead968a333e994b946a3a640a16323dbff8a8e9c',
            'corrective_importer_hash', '768cc2dc663c7723e75ca99198f60873d3c54fccb8b1fa40a1d6bda2e101c9f6',
            'mapped_to', 506
        )
    );
END $code$;

COMMIT;
