require('dotenv').config({ path: '.env.local' });
const { createClient } = require('@supabase/supabase-js');
globalThis.WebSocket = require('ws');
(async () => {
  const supabase = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY, { realtime: false, auth: { persistSession: false } });
  
  const { data, error } = await supabase.rpc('rpc_execute_sql', { sql: 'SELECT 1;' });
  console.log(error ? error.message : data);
})();
