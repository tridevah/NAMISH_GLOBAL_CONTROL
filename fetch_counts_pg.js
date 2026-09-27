require('dotenv').config({ path: '.env.local' });
const { Client } = require('pg');
const client = new Client({ connectionString: process.env.GC_DATABASE_URL });
async function run() {
  await client.connect();
  const res1 = await client.query('SELECT count(*) FROM hsn_sac_codes');
  const res2 = await client.query('SELECT count(*) FROM gst_rates');
  const res3 = await client.query('SELECT count(*) FROM unit_measurements');
  console.log(`HSN/SAC: ${res1.rows[0].count}`);
  console.log(`Tax: ${res2.rows[0].count}`);
  console.log(`Unit: ${res3.rows[0].count}`);
  await client.end();
}
run();
