async function run() {
  const url = 'https://urxgjgwrwpeplxoeobhz.supabase.co/rest/v1/rpc/rpc_get_units';
  const key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVyeGdqZ3dyd3BlcGx4b2VvYmh6Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NzcyNTA3MCwiZXhwIjoyMTAzMzAxMDcwfQ.rCKDshNvm8k9q6gjdYzZGCueuCzn8h0uhivcfvJ014Y';
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + key, 'apikey': key },
    body: JSON.stringify({ p_country_id: 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d' })
  });
  const text = await res.text();
  console.log("Total:", JSON.parse(text).total);
}
run();
