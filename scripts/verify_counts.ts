import { config } from 'dotenv';
import * as path from 'path';
config({ path: path.resolve(__dirname, '../.env.local') });
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseKey) {
    throw new Error('Missing Supabase env vars');
}

const supabaseAdmin = createClient(supabaseUrl, supabaseKey, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false }
});

(async () => {
    try {
        const { count: totalUnits } = await supabaseAdmin.from('measurement_units').select('*', { count: 'exact', head: true });
        const { count: activeUnits } = await supabaseAdmin.from('measurement_units').select('*', { count: 'exact', head: true }).eq('status', 'ACTIVE');
        const { count: inactiveUnits } = await supabaseAdmin.from('measurement_units').select('*', { count: 'exact', head: true }).eq('status', 'INACTIVE');
        const { count: totalConversions } = await supabaseAdmin.from('unit_conversions').select('*', { count: 'exact', head: true });

        console.log(`DB Counts:`);
        console.log(`Total units: ${totalUnits}`);
        console.log(`ACTIVE: ${activeUnits}`);
        console.log(`INACTIVE: ${inactiveUnits}`);
        console.log(`Conversions: ${totalConversions}`);
        
        // Also do a test search for KGM, MTR, LTR
        console.log('\nSearch test:');
        for (const term of ['KGM', 'MTR', 'LTR']) {
             const { data } = await supabaseAdmin.from('measurement_units').select('canonical_code, standard_code, name').ilike('standard_code', `%${term}%`).limit(1);
             console.log(`Search ${term}: ${JSON.stringify(data)}`);
        }
    } catch(e) {
        console.error(e);
    }
})();
