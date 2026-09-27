require('dotenv').config({ path: '.env.local' });
async function run() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const h = { 'apikey': key, 'Authorization': `Bearer ${key}` };
  
  // Read GC public data: published catalog_releases status visible?
  // catalog_releases is in catalog schema, not public. 
  // But dispatcher/src/index.ts reads via GC_DATABASE_URL directly.
  // Read dispatcher source to understand what it queries.
  
  // Check if GstRatesClient exposes a /api/data-hub/tax/gst-rates endpoint 
  // with 'published' filter that shows what's ready to publish
  
  // Check published releases via the data-hub API pattern:
  // /api/data-hub/tax/gst-rates reads from tax_rates (source) not catalog_releases
  
  // Check measurement_units sample (confirm it has the data we expect to publish)
  const mu = await fetch(`${url}/rest/v1/measurement_units?select=id,code,name,status&limit=3`, { headers: h });
  const muData = await mu.json();
  console.log('measurement_units sample:', JSON.stringify(muData).slice(0,300));
  
  // Read catalog_releases via preflight: does fn_publish_release exist?
  // fn_publish_release is in catalog schema - not reachable via REST
  // But we can check via a public wrapper if one exists
  const pubFn = await fetch(`${url}/rest/v1/rpc/publish_release`, { method: 'POST', headers: { ...h, 'Content-Type': 'application/json' }, body: JSON.stringify({ p_release_id: '00000000-0000-0000-0000-000000000000' }) });
  console.log('publish_release (catalog schema fn):', pubFn.status, JSON.stringify(await pubFn.json()).slice(0,100));
  
  // The GC bootstrap's fn_publish_release triggers on UPDATE to catalog_releases
  // It calls nextval internally. We cannot inspect current sequence value via REST.
  // Only option: read pg_sequences view if it's accessible
  const pgSeq = await fetch(`${url}/rest/v1/pg_sequences?select=schemaname,sequencename,last_value&schemaname=eq.catalog`, { headers: h });
  console.log('pg_sequences (catalog):', pgSeq.status, JSON.stringify(await pgSeq.json()).slice(0,200));
}
run();
