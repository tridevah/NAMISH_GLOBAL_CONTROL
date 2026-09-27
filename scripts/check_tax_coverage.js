async function run() {
  // Try to find country_tax_coverage table/view
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL + '/rest/v1/country_tax_coverage?limit=3';
  const res = await fetch(url, {
    headers: {
      'apikey': process.env.SUPABASE_SERVICE_ROLE_KEY,
      'Authorization': 'Bearer ' + process.env.SUPABASE_SERVICE_ROLE_KEY
    }
  });
  console.log('status:', res.status);
  const data = await res.json();
  console.log(JSON.stringify(data, null, 2));
}
run();
