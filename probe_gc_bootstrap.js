require('dotenv').config({ path: '.env.local' });
async function run() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const h = { 'apikey': key, 'Authorization': `Bearer ${key}`, 'Content-Type': 'application/json' };
  
  // GC bootstrap creates objects in 'catalog' schema and extends catalog.catalog_releases
  // PostgREST only exposes public schema, so we need a public RPC or check via information_schema RPC
  // Check via a simple existence probe function
  
  // Check catalog.catalog_sync_control - does preflight guard see it?
  // This can only be done via a SQL-executing RPC. Try a known GC public function.
  const existFn = await fetch(`${url}/rest/v1/rpc/get_catalog_status`, { method: 'POST', headers: h, body: '{}' });
  console.log('get_catalog_status:', existFn.status);
  
  // Try catalog.catalog_releases via supabase management API alternative
  // Actually, let's check the preflight: if GC bootstrap IS deployed, catalog_sync_control EXISTS
  // If NOT deployed, our bootstrap migration will run cleanly
  // We probe by looking for catalog.catalog_releases.release_sequence column
  // The only accessible evidence: did GC dispatcher's 'assign_release_sequence' trigger get created?
  const triggerFn = await fetch(`${url}/rest/v1/rpc/assign_release_sequence`, { method: 'POST', headers: h, body: '{}' });
  console.log('assign_release_sequence trigger fn:', triggerFn.status);
  
  // Check integration.delivery_state via looking for associated RPC
  const pubFn = await fetch(`${url}/rest/v1/rpc/dispatch_outbox_batch`, { method: 'POST', headers: h, body: '{}' });
  console.log('dispatch_outbox_batch:', pubFn.status);
  
  // Check integration.outbox_events - try a public view if it exists
  const oView = await fetch(`${url}/rest/v1/v_pending_outbox?select=id&limit=1`, { headers: h });
  console.log('v_pending_outbox:', oView.status);
}
run();
