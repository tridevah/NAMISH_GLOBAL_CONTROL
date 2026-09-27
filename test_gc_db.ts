import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';
dotenv.config({ path: '.env.local' });

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
  { db: { schema: 'catalog' } }
);

async function test() {
  const { data: levels } = await supabase.from('geography_levels').select('*').order('level_number');
  console.log('Levels:', JSON.stringify(levels, null, 2));
}
test();
