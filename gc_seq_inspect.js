require('dotenv').config({ path: '.env.local' });
async function run() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const h = { 'apikey': key, 'Authorization': `Bearer ${key}` };
  
  // catalog.release_seq starts at 1, increments by 1.
  // initial_sequence in catalog_sync_control is set to 1 at bootstrap time.
  // We need to read the current sequence value WITHOUT calling nextval.
  // PostgreSQL system tables: pg_sequences view is accessible if exposed.
  // Try via a read-only RPC that doesn't call nextval.
  
  // Also check outbox_events with release_sequence - are there any pending events?
  // integration.outbox_events is NOT in public schema.
  // Dispatcher reads outbox via integration.claim_delivery which is also not public.
  
  // What IS accessible: try reading published catalog_releases via their public API
  // GstRatesClient.tsx might expose published releases via a UI route
  const gcTaxRates = await fetch(`${url}/rest/v1/tax_rates?select=id,code,name,status&limit=5`, { headers: h });
  const trData = await gcTaxRates.json();
  console.log('GC tax_rates (public):', gcTaxRates.status, 'rows:', Array.isArray(trData) ? trData.length : 'ERR');
  if (Array.isArray(trData) && trData.length > 0) console.log('Sample:', JSON.stringify(trData[0]));
  
  // Try to read any catalog_releases via a dispatcher-side function
  const dispatchFn = await fetch(`${url}/rest/v1/rpc/claim_delivery`, { method: 'POST', headers: { ...h, 'Content-Type': 'application/json' }, body: JSON.stringify({ p_limit: 0 }) });
  console.log('claim_delivery (p_limit=0, read intent):', dispatchFn.status, JSON.stringify(await dispatchFn.json()).slice(0,100));
  
  // aggregate_outbox_status with a dummy event_id
  const aosFn = await fetch(`${url}/rest/v1/rpc/aggregate_outbox_status`, { method: 'POST', headers: { ...h, 'Content-Type': 'application/json' }, body: JSON.stringify({ p_event_id: '00000000-0000-0000-0000-000000000000' }) });
  console.log('aggregate_outbox_status (null event):', aosFn.status, JSON.stringify(await aosFn.json()).slice(0,100));
}
run();
