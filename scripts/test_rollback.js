const { Pool } = require('pg');
const pool = new Pool({ connectionString: 'postgresql://postgres:postgres@localhost:54522/postgres' });
async function run() {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const rel = await client.query(\INSERT INTO data_imports.releases (release_name, status, source_uri, sha256_hash) VALUES ('LGD_20260826_CORE_R12', 'EXTRACTING', 'x', 'x') RETURNING id\);
    const relId = rel.rows[0].id;
    const batch = await client.query(\INSERT INTO data_imports.batches (release_id, logical_batch_key, entity_type, status) VALUES (\, 'B1', 'VILLAGE', 'EXTRACTING') RETURNING id\, [relId]);
    const batchId = batch.rows[0].id;

    // insert A
    await client.query(\
      INSERT INTO staging.geography_imports (
        release_id, batch_id, source_observation_key, physical_source_sha256, 
        internal_member_or_sheet, physical_row_number, logical_output_ordinal, emitted_record_ordinal,
        raw_payload_sha256, entity_type, classification, raw_data
      ) VALUES (\, \, 'OBS_KEY', 'x', 'x', 1, 1, 1, 'HASH_A', 'VILLAGE', 'PENDING', '{}')
    \, [relId, batchId]);
    console.log("Payload A inserted.");

    // insert B
    try {
      await client.query(\
        INSERT INTO staging.geography_imports (
          release_id, batch_id, source_observation_key, physical_source_sha256, 
          internal_member_or_sheet, physical_row_number, logical_output_ordinal, emitted_record_ordinal,
          raw_payload_sha256, entity_type, classification, raw_data
        ) VALUES (\, \, 'OBS_KEY', 'x', 'x', 1, 1, 1, 'HASH_B', 'VILLAGE', 'PENDING', '{}')
      \, [relId, batchId]);
      console.log("Payload B inserted (FAILED - should have raised error)");
    } catch(e) {
      console.log("Raised Error:", e.message);
      console.log("SQLSTATE:", e.code);
    }

    // Prove A remains
    const remain = await client.query(\SELECT raw_payload_sha256 FROM staging.geography_imports WHERE source_observation_key='OBS_KEY'\);
    console.log("Payload remains:", remain.rows[0].raw_payload_sha256);

    await client.query('ROLLBACK');
  } finally {
    client.release();
    pool.end();
  }
}
run();
