require('dotenv').config({ path: '.env.local' });
async function run() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const h = { 'apikey': key, 'Authorization': `Bearer ${key}` };
  
  // Check if GC catalog schema objects exist (catalog_sync_control, release_seq, delivery_state, catalog_releases.release_sequence)
  // Use REST to check catalog.catalog_releases existence
  const relRes = await fetch(`${url}/rest/v1/catalog.catalog_releases?select=id&limit=1`, { headers: h });
  console.log('catalog.catalog_releases REST:', relRes.status, JSON.stringify(await relRes.json()).slice(0,100));
  
  // Check outbox_events
  const outRes = await fetch(`${url}/rest/v1/integration.outbox_events?select=id&limit=1`, { headers: h });
  console.log('integration.outbox_events REST:', outRes.status, JSON.stringify(await outRes.json()).slice(0,100));
  
  // Check delivery_state
  const dsRes = await fetch(`${url}/rest/v1/integration.delivery_state?select=id&limit=1`, { headers: h });
  console.log('integration.delivery_state REST:', dsRes.status, JSON.stringify(await dsRes.json()).slice(0,100));
  
  // Check if publication_sequence_fn exists
  const seqFn = await fetch(`${url}/rest/v1/rpc/publish_catalog_release`, { method: 'POST', headers: { ...h, 'Content-Type': 'application/json' }, body: '{}' });
  console.log('publish_catalog_release RPC:', seqFn.status, JSON.stringify(await seqFn.json()).slice(0,100));
}
run();
