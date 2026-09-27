const { Pool } = require('pg');
const crypto = require('crypto');
const pool = new Pool({ connectionString: 'postgresql://postgres:postgres@localhost:54522/postgres' });
function sha256(str) { return crypto.createHash('sha256').update(str).digest('hex'); }
async function runTests() {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const releaseRes = await client.query(`INSERT INTO data_imports.releases (release_name, status, source_uri, sha256_hash) VALUES ('LGD_20260826_CORE_R10_PAYLOAD_TEST', 'EXTRACTING', 'x', 'x') RETURNING id`);
    const releaseId = releaseRes.rows[0].id;
    const batchRes = await client.query(`INSERT INTO data_imports.batches (release_id, logical_batch_key, entity_type, status) VALUES ($1, 'TEST_BATCH_KEY', 'VILLAGE', 'EXTRACTING') RETURNING id`, [releaseId]);
    const batchId = batchRes.rows[0].id;

    async function stageWithConflictCheck(payload) {
      const obsStr = 'OBS_V1_TEST' + batchId;
      const obsKey = sha256(obsStr);
      const payloadHash = sha256(JSON.stringify(payload));
      
      const res = await client.query(`
        INSERT INTO staging.geography_imports (
          release_id, batch_id, source_observation_key, physical_source_sha256, 
          internal_member_or_sheet, physical_row_number, logical_output_ordinal, 
          emitted_record_ordinal, raw_payload_sha256, entity_type, raw_data, classification
        ) VALUES ($1, $2, $3, 'x', 'x', 1, 1, 1, $4, 'VILLAGE', '{}', 'PENDING')
        ON CONFLICT (release_id, batch_id, source_observation_key) WHERE source_observation_key IS NOT NULL DO NOTHING
        RETURNING id
      `, [releaseId, batchId, obsKey, payloadHash]);
      
      if (res.rowCount === 0) {
        const existing = await client.query(`SELECT raw_payload_sha256 FROM staging.geography_imports WHERE release_id=$1 AND batch_id=$2 AND source_observation_key=$3`, [releaseId, batchId, obsKey]);
        if (existing.rows[0].raw_payload_sha256 !== payloadHash) {
            throw new Error('OBSERVATION_KEY_COLLISION: Payload mismatch on replay');
        }
      }
    }

    await stageWithConflictCheck({a:1});
    console.log("First staged successfully.");
    try {
       await stageWithConflictCheck({a:2});
       console.log("Failed to raise exception.");
    } catch(e) {
       console.log("Raised:", e.message);
    }
  } finally {
    await client.query('ROLLBACK');
    client.release();
  }
}
runTests().then(()=>process.exit(0)).catch(console.error);
