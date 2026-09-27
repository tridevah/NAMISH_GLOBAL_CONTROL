import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';
dotenv.config({ path: '.env.local' });

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
  { db: { schema: 'catalog' } }
);

async function test() {
  const { data, error } = await supabase.from('geography_units').select('*').limit(1);
  console.log('Data:', data);
  console.log('Error:', error);
}
test();
