require('dotenv').config({ path: '.env.local' });
async function run() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const h = { 'apikey': key, 'Authorization': `Bearer ${key}`, 'Content-Type': 'application/json' };
  
  // catalog_releases is in catalog schema - not exposed via PostgREST directly
  // Try public RPCs that expose catalog state (read-only)
  
  // Does a get_catalog_releases_summary or similar exist?
  const rpcs = ['get_pending_releases', 'get_catalog_state', 'get_release_status', 'get_published_releases'];
  for (const rpc of rpcs) {
    const r = await fetch(`${url}/rest/v1/rpc/${rpc}`, { method: 'POST', headers: h, body: '{}' });
    if (r.status !== 404) console.log(`${rpc}: HTTP ${r.status} ?`, JSON.stringify(await r.json()).slice(0,100));
    else console.log(`${rpc}: 404 (not found)`);
  }
  
  // Try reading the GC bootstrap migration to understand what public views/functions exist
  console.log('\nChecking public views in schema...');
  const views = ['v_catalog_state', 'v_release_queue', 'v_outbox_pending'];
  for (const v of views) {
    const r = await fetch(`${url}/rest/v1/${v}?limit=1`, { headers: h });
    if (r.status !== 404) console.log(`${v}: HTTP ${r.status} ?`, JSON.stringify(await r.json()).slice(0,100));
    else console.log(`${v}: 404`);
  }
}
run();
