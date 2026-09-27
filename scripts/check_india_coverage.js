async function run() {
  // Check India's coverage status
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL + '/rest/v1/country_tax_coverage?country_id=eq.cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d';
  const res = await fetch(url, {
    headers: {
      'apikey': process.env.SUPABASE_SERVICE_ROLE_KEY,
      'Authorization': 'Bearer ' + process.env.SUPABASE_SERVICE_ROLE_KEY
    }
  });
  const data = await res.json();
  console.log('India coverage:', JSON.stringify(data, null, 2));
  
  // Also check the countries table directly
  const url2 = process.env.NEXT_PUBLIC_SUPABASE_URL + '/rest/v1/countries?id=eq.cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d&select=id,name,iso2,tax_coverage';
  const res2 = await fetch(url2, {
    headers: {
      'apikey': process.env.SUPABASE_SERVICE_ROLE_KEY,
      'Authorization': 'Bearer ' + process.env.SUPABASE_SERVICE_ROLE_KEY
    }
  });
  console.log('Countries table status:', res2.status);
  const data2 = await res2.json();
  console.log('Countries table India:', JSON.stringify(data2, null, 2));
}
run();
