const { Pool } = require('pg');
const pool = new Pool({ connectionString: 'postgresql://postgres:postgres@localhost:54522/postgres' });
async function run() {
  const client = await pool.connect();
  try {
    const res = await client.query("SELECT id FROM data_imports.releases WHERE release_name='LGD_20260826_CORE_R12'");
    if(res.rows.length > 0) {
       const rid = res.rows[0].id;
       console.log('Found R12:', rid);
       console.log('Deleting remaining staging...');
       let deleted = 1;
       while(deleted > 0) {
           const d = await client.query("DELETE FROM staging.geography_imports WHERE release_id=$1 AND id IN (SELECT id FROM staging.geography_imports WHERE release_id=$1 LIMIT 50000)", [rid]);
           deleted = d.rowCount;
           console.log('Deleted staging:', deleted);
       }
       console.log('Deleting batches...');
       await client.query("DELETE FROM data_imports.batches WHERE release_id=$1", [rid]);
       console.log('Deleting release...');
       await client.query("DELETE FROM data_imports.releases WHERE id=$1", [rid]);
       console.log('R12 completely purged.');
    } else {
       console.log('No R12 found');
    }
  } finally {
    client.release();
    pool.end();
  }
}
run();
