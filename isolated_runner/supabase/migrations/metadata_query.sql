SELECT 
    status as release_status,
    completed_at as release_completed_at,
    (SELECT count(*) FROM data_imports.batches WHERE release_id = r.id) as total_batches,
    (SELECT count(*) FROM data_imports.batches WHERE release_id = r.id AND status = 'FINALIZED') as finalized_batches,
    (SELECT count(*) FROM data_imports.batches WHERE release_id = r.id AND status = 'OFFICIAL_EMPTY') as official_empty_batches,
    (SELECT count(*) FROM data_imports.batches WHERE release_id = r.id AND status NOT IN ('FINALIZED', 'OFFICIAL_EMPTY')) as other_statuses,
    (SELECT count(*) FROM data_imports.release_execution_artifacts WHERE release_id = r.id AND artifact_type = 'PROMOTION_EVIDENCE') as evidence_artifacts
FROM data_imports.releases r
WHERE id = '5fac63d7-0101-43c5-8867-bd75ff609861';
