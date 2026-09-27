const { createClient } = require('@supabase/supabase-js');
globalThis.WebSocket = require('ws');

(async () => {
  const supabase = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY,
    {
      realtime: false,
      auth: { persistSession: false }
    }
  );

  const { data: countries, error: e1 } = await supabase.rpc('rpc_get_countries');
  console.log('rpc_get_countries (all):', e1 || `Returned ${countries.length} countries`);
  
  const india = countries ? countries.find(c => c.iso2 === 'IN') : null;
  const afghanistan = countries ? countries.find(c => c.iso2 === 'AF') : null;
  
  console.log('\nIndia in RPC:', india);
  console.log('Afghanistan in RPC:', afghanistan);

  console.log('\n--- 3. Call rpc_get_units directly with fixed India UUID ---');
  const { data: rpcUnits, error: e4 } = await supabase.rpc('rpc_get_units', {
    p_country_id: 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d'
  });
  console.log('\nrpc_get_units (fixed UUID):', e4 ? e4 : `Count: ${rpcUnits ? rpcUnits.length : 0}`);

  console.log('\n--- 4. Call rpc_get_units directly with ACTUAL India UUID from RPC ---');
  if (india) {
    const { data: rpcUnits2, error: e5 } = await supabase.rpc('rpc_get_units', {
      p_country_id: india.id
    });
    console.log('\nrpc_get_units (RPC UUID):', e5 ? e5 : `Count: ${rpcUnits2 ? rpcUnits2.length : 0}`);
  }
})();
