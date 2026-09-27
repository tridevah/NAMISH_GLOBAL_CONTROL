require('dotenv').config({ path: '.env.local' });
async function run() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const headers = { 'apikey': key, 'Authorization': `Bearer ${key}`, 'Prefer': 'count=exact' };
  const hsn = await fetch(`${url}/rest/v1/hsn_sac?select=id`, { headers, method: 'HEAD' });
  const tax = await fetch(`${url}/rest/v1/tax_rates?select=id`, { headers, method: 'HEAD' });
  const unit = await fetch(`${url}/rest/v1/measurement_units?select=id`, { headers, method: 'HEAD' });
  
  console.log(`HSN/SAC:`, hsn.headers.get('content-range'));
  console.log(`Tax Rates:`, tax.headers.get('content-range'));
  console.log(`Measurement Units:`, unit.headers.get('content-range'));
}
run();
