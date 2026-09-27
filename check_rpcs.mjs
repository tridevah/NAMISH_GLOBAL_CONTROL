import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';
dotenv.config({ path: '.env.local' });

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const supabase = createClient(supabaseUrl, supabaseKey);

async function check() {
    const { data: rpcs } = await supabase.rpc('rpc_get_country_currencies', { p_search: '' }).limit(1).catch(() => ({}));
    // Let's list functions in public schema
    const { data, error } = await supabase.from('pg_proc').select('proname').like('proname', '%geo%');
    console.log(JSON.stringify({error}, null, 2));
}
check();
