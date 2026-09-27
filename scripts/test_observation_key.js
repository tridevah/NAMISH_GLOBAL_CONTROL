const { Pool } = require('pg');
const crypto = require('crypto');

const pool = new Pool({ connectionString: 'postgresql://postgres:postgres@localhost:54522/postgres' });

function sha256(str) { return crypto.createHash('sha256').update(str).digest('hex'); }

async function runTests() {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    
    // Setup dummy release and batch
    const releaseRes = await client.query(`
      INSERT INTO data_imports.releases (release_name, status, source_uri, sha256_hash) 
      VALUES ('LGD_20260826_CORE_R10', 'EXTRACTING', 'x', 'x') RETURNING id`);
    const releaseId = releaseRes.rows[0].id;
    
    const batchRes = await client.query(`
      INSERT INTO data_imports.batches (release_id, logical_batch_key, entity_type, status) 
      VALUES ($1, 'TEST_BATCH_KEY', 'VILLAGE', 'EXTRACTING') RETURNING id`, [releaseId]);
    const batchId = batchRes.rows[0].id;

    // Helper to insert
    async function insertStaging(physRowNumber, payload, logicalOrdinal=1, emittedOrdinal=1, sheet='sheet1', srcHash='hash1') {
      const normalizedSheet = sheet.replace(/\\/g, '/').normalize('NFC');
      const obsStr = 'OBS_V1' + srcHash + normalizedSheet + physRowNumber + 'TEST_BATCH_KEY' + logicalOrdinal + emittedOrdinal;
      const obsKey = sha256(obsStr);
      const payloadStr = JSON.stringify(payload);
      const payloadHash = sha256(payloadStr);

      const q = `
        INSERT INTO staging.geography_imports (
          release_id, batch_id, source_observation_key, physical_source_sha256, 
          internal_member_or_sheet, physical_row_number, logical_output_ordinal, 
          emitted_record_ordinal, raw_payload_sha256, entity_type, entity_code, classification, raw_data
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
        ON CONFLICT (release_id, batch_id, source_observation_key) 
        WHERE source_observation_key IS NOT NULL DO NOTHING
        RETURNING id
      `;
      const res = await client.query(q, [
        releaseId, batchId, obsKey, srcHash, normalizedSheet, physRowNumber, 
        logicalOrdinal, emittedOrdinal, payloadHash, 'VILLAGE', payload.code||null, 'PENDING', payloadStr
      ]);
      return { inserted: res.rowCount > 0, obsKey, payloadHash };
    }

    console.log('--- TEST A ---');
    const a1 = await insertStaging(10, {code: '123'});
    const a2 = await insertStaging(20, {code: '123'});
    console.log('A: Rows=2, Keys=', new Set([a1.obsKey, a2.obsKey]).size, 'Staged=', (a1.inserted?1:0)+(a2.inserted?1:0));

    console.log('--- TEST B ---');
    const b1 = await insertStaging(30, {code: '456'});
    const b2 = await insertStaging(30, {code: '456'});
    console.log('B: First=', b1.inserted, 'Second=', b2.inserted);

    console.log('--- TEST D ---');
    try {
      await client.query(`INSERT INTO staging.geography_imports (batch_id, release_id, source_observation_key, physical_row_number) VALUES ($1, $2, $3, $4) ON CONFLICT(release_id, batch_id, source_observation_key) WHERE source_observation_key IS NOT NULL DO NOTHING`, [batchId, releaseId, a1.obsKey, null]); 
      console.log('D: Failed to raise');
    } catch(e) {
      console.log('D: Raised', e.message);
    }
    
  } finally {
    await client.query('ROLLBACK');
    client.release();
  }
}
runTests().catch(console.error).finally(()=>process.exit(0));
