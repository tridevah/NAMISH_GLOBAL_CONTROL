import { config } from 'dotenv';
config({ path: '.env.local' });
import { createAdminClient } from './src/utils/supabase/admin';

(async () => {
    const { data, error } = await createAdminClient().from('uqc').select('*');
    console.log(data);
})();
