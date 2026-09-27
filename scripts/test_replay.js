const { Pool } = require('pg');
const pool = new Pool({ connectionString: 'postgresql://postgres:postgres@localhost:54522/postgres' });
async function run() {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const rel = await client.query(`INSERT INTO data_imports.releases (release_name, status, source_uri, sha256_hash) VALUES ('LGD_TEST_REVIEWS', 'EXTRACTING', 'x', 'x') RETURNING id`);
    const relId = rel.rows[0].id;
    const batch = await client.query(`INSERT INTO data_imports.batches (release_id, logical_batch_key, entity_type, status) VALUES ($1, 'B1', 'VILLAGE', 'EXTRACTING') RETURNING id`, [relId]);
    const batchId = batch.rows[0].id;

    // Test row_errors
    await client.query(`
      INSERT INTO data_imports.row_errors (release_id, batch_id, source_observation_key, error_or_review_code, occurrence_count, row_data, error_message) 
      VALUES ($1, $2, 'OBS_KEY', 'ERR1', 1, '{}', 'err')
      ON CONFLICT (release_id, batch_id, source_observation_key, error_or_review_code) WHERE source_observation_key IS NOT NULL
      DO UPDATE SET occurrence_count = data_imports.row_errors.occurrence_count + 1
    `, [relId, batchId]);

    let res1 = await client.query(`SELECT count(*) as rows, max(occurrence_count) as occ FROM data_imports.row_errors WHERE release_id=$1`, [relId]);
    console.log("FIRST_INSERT row_errors: rows =", res1.rows[0].rows, "occurrence_count =", res1.rows[0].occ);

    await client.query(`
      INSERT INTO data_imports.row_errors (release_id, batch_id, source_observation_key, error_or_review_code, occurrence_count, row_data, error_message) 
      VALUES ($1, $2, 'OBS_KEY', 'ERR1', 1, '{}', 'err')
      ON CONFLICT (release_id, batch_id, source_observation_key, error_or_review_code) WHERE source_observation_key IS NOT NULL
      DO UPDATE SET occurrence_count = data_imports.row_errors.occurrence_count + 1
    `, [relId, batchId]);

    let res2 = await client.query(`SELECT count(*) as rows, max(occurrence_count) as occ FROM data_imports.row_errors WHERE release_id=$1`, [relId]);
    console.log("SECOND_IDENTICAL_REPLAY row_errors: rows =", res2.rows[0].rows, "occurrence_count =", res2.rows[0].occ);

    // Test post_office_identity_reviews
    await client.query(`
      INSERT INTO catalog.post_office_identity_reviews (release_id, identity_version, identity_key, source_observation_key, occurrence_count, conflicting_row_data, reason) 
      VALUES ($1, 'V1', 'ID1', 'OBS_KEY', 1, '{}', 'reason')
      ON CONFLICT (release_id, identity_version, identity_key, source_observation_key) WHERE source_observation_key IS NOT NULL
      DO UPDATE SET occurrence_count = catalog.post_office_identity_reviews.occurrence_count + 1
    `, [relId]);

    res1 = await client.query(`SELECT count(*) as rows, max(occurrence_count) as occ FROM catalog.post_office_identity_reviews WHERE release_id=$1`, [relId]);
    console.log("FIRST_INSERT reviews: rows =", res1.rows[0].rows, "occurrence_count =", res1.rows[0].occ);

    await client.query(`
      INSERT INTO catalog.post_office_identity_reviews (release_id, identity_version, identity_key, source_observation_key, occurrence_count, conflicting_row_data, reason) 
      VALUES ($1, 'V1', 'ID1', 'OBS_KEY', 1, '{}', 'reason')
      ON CONFLICT (release_id, identity_version, identity_key, source_observation_key) WHERE source_observation_key IS NOT NULL
      DO UPDATE SET occurrence_count = catalog.post_office_identity_reviews.occurrence_count + 1
    `, [relId]);

    res2 = await client.query(`SELECT count(*) as rows, max(occurrence_count) as occ FROM catalog.post_office_identity_reviews WHERE release_id=$1`, [relId]);
    console.log("SECOND_IDENTICAL_REPLAY reviews: rows =", res2.rows[0].rows, "occurrence_count =", res2.rows[0].occ);

    await client.query('ROLLBACK');
  } finally {
    client.release();
    pool.end();
  }
}
run();
