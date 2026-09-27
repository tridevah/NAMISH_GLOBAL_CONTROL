async function run() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL + '/rest/v1/countries?id=eq.cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d&select=*&limit=1';
  const res = await fetch(url, {
    headers: {
      'apikey': process.env.SUPABASE_SERVICE_ROLE_KEY,
      'Authorization': 'Bearer ' + process.env.SUPABASE_SERVICE_ROLE_KEY
    }
  });
  const data = await res.json();
  console.log('Countries public schema columns:', Object.keys(data[0] || {}));
}
run();
