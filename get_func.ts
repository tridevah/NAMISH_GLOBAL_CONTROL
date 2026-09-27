import { createClient } from '@supabase/supabase-js';

global.WebSocket = class {} as any;

const adminSupabase = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
  { auth: { autoRefreshToken: false, persistSession: false } }
);

async function test() {
    const query = "SELECT pg_get_functiondef(oid) FROM pg_proc WHERE proname = 'rpc_get_country_currencies'";
    const { data, error } = await adminSupabase.rpc('rpc_execute_sql', { sql: query });
    if (error) console.error(error);
    else console.log(JSON.stringify(data, null, 2));
}
test();
