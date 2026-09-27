import * as dotenv from 'dotenv';
dotenv.config({ path: '.env.local' });
import { createClient } from '@supabase/supabase-js';

async function test() {
    const res = await fetch(process.env.NEXT_PUBLIC_SUPABASE_URL + '/rest/v1/?apikey=' + process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY);
    const data = await res.json();
    console.log(Object.keys(data.paths).filter(p => p.includes('rpc_execute_sql')));
}
test();
