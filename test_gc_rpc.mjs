import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';
dotenv.config({ path: '.env.local' });

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const supabase = createClient(supabaseUrl, supabaseKey);

async function check() {
    const { data: levels } = await supabase.rpc('rpc_get_levels', { p_country_id: 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d' });
    console.log('Levels:', JSON.stringify(levels, null, 2));

    const { data: units } = await supabase.rpc('rpc_get_units', { p_country_id: 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', p_limit: 5 });
    console.log('Units:', JSON.stringify(units, null, 2));
}
check();
