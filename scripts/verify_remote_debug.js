const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;

async function check() {
  const res = await fetch(url + '/rest/v1/?apikey=' + key, {
      headers: { 'Authorization': 'Bearer ' + key }
  });
  const data = await res.json();
  console.log(Object.keys(data.paths).filter(p => !p.startsWith('/rpc/')));
}
check();
