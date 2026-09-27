async function run() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL + '/auth/v1/admin/users';
  const res = await fetch(url, {
    headers: {
      'apikey': process.env.SUPABASE_SERVICE_ROLE_KEY,
      'Authorization': 'Bearer ' + process.env.SUPABASE_SERVICE_ROLE_KEY
    }
  });
  const data = await res.json();
  console.log(data.users.map(u => u.email));
}
run();
