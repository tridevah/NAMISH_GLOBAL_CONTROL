require('dotenv').config({ path: '.env.local' });
const { createClient } = require('@supabase/supabase-js');
const supabase = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);

async function run() {
  const { count: hsnCount } = await supabase.from('hsn_sac_codes').select('*', { count: 'exact', head: true });
  const { count: taxCount } = await supabase.from('gst_rates').select('*', { count: 'exact', head: true });
  const { count: unitCount } = await supabase.from('unit_measurements').select('*', { count: 'exact', head: true });
  
  console.log(`HSN/SAC: ${hsnCount}`);
  console.log(`Tax: ${taxCount}`);
  console.log(`Unit: ${unitCount}`);
}
run();
