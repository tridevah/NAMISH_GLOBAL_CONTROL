require('dotenv').config({ path: '.env.local' });
async function run() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const headers = { 'apikey': key, 'Authorization': `Bearer ${key}` };
  const hsn = await (await fetch(`${url}/rest/v1/hsn_sac?select=id`, { headers })).json();
  const unit = await (await fetch(`${url}/rest/v1/measurement_units?select=id`, { headers })).json();
  
  console.log(`HSN/SAC:`, hsn.length);
  console.log(`Unit:`, unit.length);
}
run();
