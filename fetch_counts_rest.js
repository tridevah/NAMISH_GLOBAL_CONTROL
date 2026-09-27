require('dotenv').config({ path: '.env.local' });
async function run() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  
  const headers = { 'apikey': key, 'Authorization': `Bearer ${key}`, 'Range-Unit': 'items' };
  
  const [hsn, tax, unit] = await Promise.all([
    fetch(`${url}/rest/v1/hsn_sac_codes?select=*`, { headers: { ...headers, 'Prefer': 'count=exact', 'Range': '0-0' } }),
    fetch(`${url}/rest/v1/gst_rates?select=*`, { headers: { ...headers, 'Prefer': 'count=exact', 'Range': '0-0' } }),
    fetch(`${url}/rest/v1/unit_measurements?select=*`, { headers: { ...headers, 'Prefer': 'count=exact', 'Range': '0-0' } })
  ]);
  
  console.log(`HSN/SAC:`, hsn.headers.get('content-range'));
  console.log(`Tax:`, tax.headers.get('content-range'));
  console.log(`Unit:`, unit.headers.get('content-range'));
}
run();
