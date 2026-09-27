import { createClient } from '@supabase/supabase-js';

global.WebSocket = class {} as any;

const adminSupabase = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
  { auth: { autoRefreshToken: false, persistSession: false } }
);

async function test() {
    const { data: currencyData, error: currencyError } = await adminSupabase.rpc('rpc_get_country_currencies');
    console.log(currencyError || (currencyData && currencyData.slice(0, 2)));
}
test();
