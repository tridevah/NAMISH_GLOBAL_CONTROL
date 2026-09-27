require('dotenv').config({ path: '.env.local' });
async function run() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const h = { 'apikey': key, 'Authorization': `Bearer ${key}` };
  
  // catalog_releases: check if it has release_sequence column (GC bootstrap adds it)
  // Select known cols first, then try release_sequence
  const r1 = await fetch(`${url}/rest/v1/catalog_releases?select=id,status,published_at,created_at&limit=10&order=created_at.desc`, { headers: h });
  console.log('catalog_releases status/cols:', r1.status);
  const d1 = await r1.json();
  if (Array.isArray(d1)) {
    console.log('rows:', d1.length, d1.length > 0 ? JSON.stringify(d1[0]).slice(0,200) : '(empty)');
    
    // Try release_sequence col - proves bootstrap was applied
    const r2 = await fetch(`${url}/rest/v1/catalog_releases?select=id,status,release_sequence&limit=5&order=release_sequence.desc`, { headers: h });
    const d2 = await r2.json();
    console.log('catalog_releases with release_sequence:', r2.status, JSON.stringify(d2).slice(0,200));
  } else {
    console.log('Error:', JSON.stringify(d1).slice(0,200));
  }
}
run();
