require('dotenv').config({ path: '.env.local' });
async function run() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const h = { 'apikey': key, 'Authorization': `Bearer ${key}`, 'Content-Type': 'application/json' };
  
  // GC bootstrap creates catalog.fn_validate_release_items, integration.claim_delivery
  // None of these are in public schema, so all 404 via REST is expected WHETHER OR NOT deployed.
  // We cannot distinguish deployed vs not-deployed via PostgREST for non-public functions.
  
  // The PREFLIGHT guard in GC bootstrap checks for catalog.catalog_sync_control
  // and catalog.release_seq and integration.delivery_state and catalog_releases.release_sequence
  // If any of those exist, it raises exception.
  
  // One way to check: try a raw SQL via the Supabase pg meta API (if accessible)
  // But we don't have pg meta access via REST.
  
  // Alternative: check via the GC bootstrap's own internal assertion
  // The user said "GC 20260925000000 bootstrap PREVIOUSLY DEPLOYED"
  // Let's verify that by checking what the dispatcher bootstrap creates vs what exists
  
  // GC bootstrap creates integration.delivery_state
  // The dispatcher polls integration.outbox_events and delivery_state
  // If dispatcher's index.ts relies on catalog.catalog_releases.release_sequence, 
  // then if bootstrap NOT deployed, dispatcher would fail on first poll
  
  // Check if there's a catalog_releases view in public schema
  const crView = await fetch(`${url}/rest/v1/catalog_releases?select=id,status&limit=1`, { headers: h });
  console.log('catalog_releases (as public view):', crView.status, JSON.stringify(await crView.json()).slice(0,150));
  
  // The user's statement is authoritative - let's accept that GC bootstrap IS deployed
  // and focus on verifiable evidence
  console.log('CONCLUSION: GC bootstrap deployment state cannot be verified via REST API alone.');
  console.log('User statement accepted: GC 20260925000000 = DEPLOYED');
}
run();
