require('dotenv').config({ path: '.env.local' });
const url = process.env.NEXT_PUBLIC_SUPABASE_URL + '/rest/v1/rpc/rpc_get_units';
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;

async function run() {
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ' + key,
      'apikey': key
    },
    body: JSON.stringify({
      p_country_id: 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d',
      p_level_id: '1b6e5e2a-db7c-d9ee-073e-dbb807ed0caf',
      p_parent_id: null,
      p_status: null,
      p_search: null,
      p_limit: 200,
      p_offset: 0
    })
  });
  const text = await res.text();
  console.log("Status:", res.status);
  console.log("Response:", text.substring(0, 1000)); // print first 1000 chars
}
run();
