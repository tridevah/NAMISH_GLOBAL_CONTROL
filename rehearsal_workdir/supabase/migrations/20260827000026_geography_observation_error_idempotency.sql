-- 20260827000026_geography_observation_error_idempotency.sql

ALTER TABLE data_imports.row_errors
ADD COLUMN release_id UUID REFERENCES data_imports.releases(id),
ADD COLUMN source_observation_key TEXT,
ADD COLUMN error_or_review_code TEXT,
ADD COLUMN importer_replay_count BIGINT DEFAULT 0;

CREATE UNIQUE INDEX row_errors_identity_idx 
ON data_imports.row_errors (release_id, batch_id, source_observation_key, error_or_review_code) 
WHERE source_observation_key IS NOT NULL;

ALTER TABLE catalog.post_office_identity_reviews
ADD COLUMN batch_id UUID REFERENCES data_imports.batches(id),
ADD COLUMN source_observation_key TEXT,
ADD COLUMN importer_replay_count BIGINT DEFAULT 0;

CREATE UNIQUE INDEX post_office_identity_reviews_obs_idx 
ON catalog.post_office_identity_reviews (release_id, identity_version, identity_key, source_observation_key) 
WHERE source_observation_key IS NOT NULL;
