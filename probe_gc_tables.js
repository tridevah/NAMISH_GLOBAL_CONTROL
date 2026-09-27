require('dotenv').config({ path: '.env.local' });
async function run() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const h = { 'apikey': key, 'Authorization': `Bearer ${key}` };
  
  // PostgREST only sees public schema - use known GC tables
  const taxRates = await fetch(`${url}/rest/v1/tax_rates?select=id&limit=1`, { headers: h });
  console.log('tax_rates (public):', taxRates.status, JSON.stringify(await taxRates.json()).slice(0,100));
  
  const hsnSac = await fetch(`${url}/rest/v1/hsn_sac?select=id&limit=1`, { headers: h });
  console.log('hsn_sac (public):', hsnSac.status, JSON.stringify(await hsnSac.json()).slice(0,100));
  
  // Check if any catalog_releases table is accessible via a public RPC
  const relRpc = await fetch(`${url}/rest/v1/rpc/get_catalog_releases`, { method: 'POST', headers: { ...h, 'Content-Type': 'application/json' }, body: '{}' });
  console.log('get_catalog_releases RPC:', relRpc.status);
  
  // Try catalog_releases via a different schema path
  const crRes2 = await fetch(`${url}/rest/v1/catalog_releases?select=id,status,release_sequence&limit=5`, { headers: h });
  console.log('catalog_releases (public):', crRes2.status, JSON.stringify(await crRes2.json()).slice(0,200));
  
  // outbox_events in public?
  const obRes = await fetch(`${url}/rest/v1/outbox_events?select=id,status&limit=5`, { headers: h });
  console.log('outbox_events (public):', obRes.status, JSON.stringify(await obRes.json()).slice(0,200));
}
run();
