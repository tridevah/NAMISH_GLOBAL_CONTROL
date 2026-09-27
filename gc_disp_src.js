require('dotenv').config({ path: '.env.local' });
async function run() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const h = { 'apikey': key, 'Authorization': `Bearer ${key}` };
  
  // measurement_units has no 'code' col. Check actual cols:
  const mu = await fetch(`${url}/rest/v1/measurement_units?select=*&limit=2`, { headers: h });
  const muData = await mu.json();
  console.log('measurement_units full cols:', Array.isArray(muData) && muData.length > 0 ? Object.keys(muData[0]).join(', ') : JSON.stringify(muData).slice(0,200));
  
  // Check catalog_releases via a different approach: the dispatcher reads it via GC_DATABASE_URL
  // Read dispatcher source to understand query structure
  const fs = require('fs');
  const dispSrc = fs.readFileSync('dispatcher/src/index.ts', 'utf8');
  const lines = dispSrc.split('\n');
  // Find lines with catalog_releases or release_sequence or outbox_events
  const relevant = lines.filter(l => l.includes('catalog_releases') || l.includes('release_sequence') || l.includes('outbox_events') || l.includes('claim_delivery') || l.includes('last_value') || l.includes('release_seq'));
  console.log('\nDispatcher catalog_releases/sequence refs:');
  relevant.forEach((l, i) => console.log(`  ${l.trim()}`));
}
run();
