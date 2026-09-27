const fs = require('fs');
const { Pool } = require('pg');
const pool = new Pool({ connectionString: 'postgresql://postgres:postgres@localhost:54522/postgres' });
async function run() {
  const client = await pool.connect();
  let lastHbTime = 0;
  try {
    while(true) {
      const bRes = await client.query("SELECT status, count(*) FROM data_imports.batches WHERE release_id='b3573f9b-1eff-47d5-8cdf-fba3eba74b19' GROUP BY status");
      let pending=0, extracting=0, staged=0, empty=0, failed=0;
      for (const r of bRes.rows) {
        if (r.status === 'PENDING') pending = parseInt(r.count);
        if (r.status === 'EXTRACTING') extracting = parseInt(r.count);
        if (r.status === 'STAGED') staged = parseInt(r.count);
        if (r.status === 'OFFICIAL_EMPTY') empty = parseInt(r.count);
        if (r.status === 'FAILED') failed = parseInt(r.count);
      }
      
      const hb = JSON.parse(fs.readFileSync('D:\\\\ANTIGRAVITY_WORKSPACE\\\\LGD_IMPORT_RUNTIME\\\\R12\\\\heartbeat.json', 'utf8'));
      const hbTime = new Date(hb.time).getTime();
      
      if (failed > 0) {
        console.log('R12_FAILED'); return;
      }
      if (pending === 0 && extracting === 0 && (staged + empty) === 506) {
        console.log('R12_PHASE_A_COMPLETE'); return;
      }
      
      if (Date.now() - hbTime > 300000) { // 5 minutes stale
        console.log('R12_STALE_HEARTBEAT'); return;
      }
      
      // wait 30 seconds
      await new Promise(r => setTimeout(r, 30000));
    }
  } finally {
    client.release();
    pool.end();
  }
}
run();
