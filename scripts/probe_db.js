require('dotenv').config({ path: '.env.local' });
const { createClient } = require('@supabase/supabase-js');
globalThis.WebSocket = require('ws');
(async () => {
  const supabase = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY, { realtime: false, auth: { persistSession: false } });
  
  // Try querying tax_authorities directly via REST
  const { data, error } = await supabase.from('tax_authorities').select('*').limit(1);
  console.log('tax_authorities REST query:', error ? error.message : 'Success');
  
  // Also try RPCs
  const { data: rpcData, error: rpcError } = await supabase.rpc('rpc_get_tax_authorities');
  console.log('rpc_get_tax_authorities:', rpcError ? rpcError.message : 'Success');
})();
