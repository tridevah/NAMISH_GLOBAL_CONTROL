const { createClient } = require('@supabase/supabase-js');

(async () => {
  // Use node fetch to avoid websocket issues with realtime-js in node v20.20
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  async function query(path) {
    const res = await fetch(`${supabaseUrl}/rest/v1/${path}`, {
      headers: {
        'apikey': supabaseKey,
        'Authorization': `Bearer ${supabaseKey}`,
        'Accept-Profile': 'catalog',
        'Content-Type': 'application/json'
      }
    });
    return await res.json();
  }

  console.log('--- 1. Query country row for fixed India UUID ---');
  const indiaRow = await query(`countries?id=eq.cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d`);
  console.log('India Row:', JSON.stringify(indiaRow, null, 2));

  console.log('\n--- 2. Query IDs and ISO codes for India and Afghanistan ---');
  const inAfRows = await query(`countries?iso2=in.(IN,AF)&select=id,iso2,iso3,name`);
  console.log('IN/AF Rows:', JSON.stringify(inAfRows, null, 2));

  console.log('\n--- 3. Count geography levels and units grouped by country_id ---');
  // Supabase REST doesn't support group by easily without RPC, but we can just query the tables directly if they are small or use pg through a client. Since we need to query DB directly, we can use a small Postgres script or RPC if available. Wait, we can fetch all levels and count their units.
  const levels = await query(`geography_levels?select=country_id,level_key`);
  console.log('Levels:', JSON.stringify(levels, null, 2));
  
  // Actually let's query geography units count directly
  const unitCountsIN = await query(`geography_units?country_id=eq.cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d&select=country_id`);
  console.log(`Units for India fixed UUID: ${unitCountsIN.length}`);
})();
