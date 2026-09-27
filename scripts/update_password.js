async function run() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL + '/auth/v1/admin/users';
  const res = await fetch(url, {
    headers: { 'apikey': process.env.SUPABASE_SERVICE_ROLE_KEY, 'Authorization': 'Bearer ' + process.env.SUPABASE_SERVICE_ROLE_KEY }
  });
  const data = await res.json();
  const admin = data.users.find(u => u.email === 'admin@tridevah.com');
  if (admin) {
    const updateRes = await fetch(url + '/' + admin.id, {
      method: 'PUT',
      headers: {
        'apikey': process.env.SUPABASE_SERVICE_ROLE_KEY,
        'Authorization': 'Bearer ' + process.env.SUPABASE_SERVICE_ROLE_KEY,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ password: 'password123', email_confirm: true })
    });
    console.log(await updateRes.json());
  }
}
run();
