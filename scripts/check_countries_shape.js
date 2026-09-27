async function run() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL + '/rest/v1/rpc/rpc_get_countries';
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'apikey': process.env.SUPABASE_SERVICE_ROLE_KEY,
      'Authorization': 'Bearer ' + process.env.SUPABASE_SERVICE_ROLE_KEY,
      'Content-Type': 'application/json'
    },
    body: '{}'
  });
  const data = await res.json();
  // find India
  const india = data.find(c => c.iso2 === 'IN');
  console.log(JSON.stringify(india, null, 2));
}
run();
