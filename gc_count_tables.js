require('dotenv').config({ path: '.env.local' });
async function run() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const h = { 'apikey': key, 'Authorization': `Bearer ${key}` };
  
  // All GC catalog/integration functions are schema-scoped (not public)
  // PostgREST cannot expose them. Only service_role direct DB connection works.
  // Dispatcher itself reads via pg connection string (GC_DATABASE_URL), not REST.
  
  // Read what IS public in GC: known tables
  const tables = ['tax_rates', 'hsn_sac', 'units', 'measurement_units'];
  for (const t of tables) {
    const r = await fetch(`${url}/rest/v1/${t}?select=id&limit=1`, { headers: h });
    if (r.status === 200) {
      const d = await r.json();
      console.log(`${t}: 200, count probe...`);
      const rc = await fetch(`${url}/rest/v1/${t}?select=id`, { headers: { ...h, 'Prefer': 'count=exact', 'Range-Unit': 'items', 'Range': '0-0' } });
      console.log(`  total rows: ${rc.headers.get('content-range')}`);
    } else {
      console.log(`${t}: ${r.status}`);
    }
  }
  
  // Read catalog.catalog_releases count via a known GC data-hub API route
  // The GstRatesClient.tsx talks to /api/data-hub/tax/gst-rates (internal Next.js route)
  // We can't call that, but we can check the underlying data:
  // tax_rates table has the source data that GC publishes
  const tr = await fetch(`${url}/rest/v1/tax_rates?select=id`, { headers: { ...h, 'Prefer': 'count=exact', 'Range-Unit': 'items', 'Range': '0-0' } });
  console.log('\ntax_rates total:', tr.headers.get('content-range'));
  
  const hsn = await fetch(`${url}/rest/v1/hsn_sac?select=id`, { headers: { ...h, 'Prefer': 'count=exact', 'Range-Unit': 'items', 'Range': '0-0' } });
  console.log('hsn_sac total:', hsn.headers.get('content-range'));
}
run();
