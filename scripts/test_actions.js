const { createAdminClient } = require('./src/utils/supabase/admin');
require('dotenv').config({ path: '.env.local' }); // points to LOCAL now

async function run() {
  const admin = createAdminClient();
  const { data, error } = await admin.rpc('rpc_get_units', {
    p_country_id: 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d',
    p_level_id: null, // all levels
    p_parent_id: null,
    p_status: null,
    p_search: null,
    p_limit: 200,
    p_offset: 0
  });
  console.log("Error:", error);
  if (data) {
    console.log("Total:", data.total);
    console.log("Rows returned:", data.rows ? data.rows.length : 0);
  }
}
run().catch(console.error);
