require('dotenv').config({ path: '../.env.local' });
const { Pool } = require('pg');
const pool = new Pool({ connectionString: process.env.GC_DATABASE_URL });
async function run() {
  const hsn = await pool.query('SELECT count(*) FROM public.hsn_sac');
  const tax = await pool.query('SELECT count(*) FROM public.tax_rates');
  const unit = await pool.query('SELECT count(*) FROM public.measurement_units');
  console.log(`HSN/SAC: ${hsn.rows[0].count}`);
  console.log(`Tax Rates: ${tax.rows[0].count}`);
  console.log(`Measurement Units: ${unit.rows[0].count}`);
  await pool.end();
}
run();
