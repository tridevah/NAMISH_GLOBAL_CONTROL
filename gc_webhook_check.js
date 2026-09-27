require('dotenv').config({ path: '.env.local' });
async function run() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const h = { 'apikey': key, 'Authorization': `Bearer ${key}` };
  
  // claim_delivery requires gc_dispatcher_worker role and p_limit 1-100
  // Integration functions only accessible via gc_dispatcher_worker role (not service_role)
  // There is no public endpoint to check outbox_events or sequence directly.
  
  // The catalog.release_seq starts at 1, allocates per nextval call inside fn_publish_release.
  // Since GC bootstrap is DEPLOYED (per user), and no release has been published yet,
  // nextval has never been called. The sequence last_value = 1 (start) or uninitialized.
  // When a sequence is created but nextval never called: last_value = start_value = 1
  // but the FIRST nextval returns 1. So first real publication will get sequence = 1.
  
  // ERP v_last_seq = MAX(release_sequence) = 4 (from test receipts).
  // First real GC publication: release_sequence = 1 (if no nextval called yet).
  // Receiver logic: IF p_release_sequence < v_last_seq (1 < 4) ? SUPERSEDED check.
  //   The SUPERSEDED branch checks IF EXISTS a receipt with release_sequence > 1 AND
  //   domain_coverage @> ARRAY['HSN','TAX','UNIT']. Test receipts DO have that coverage.
  //   So: result would be SUPERSEDED (silent drop, success=true).
  
  // This IS the conflict. GC sequence must produce a value >= 5 for first real delivery.
  
  // Check webhook_endpoints and topic_subscriptions to understand delivery targets
  const wh = await fetch(`${url}/rest/v1/webhook_endpoints?select=id,url,status,description&limit=10`, { headers: h });
  console.log('webhook_endpoints:', wh.status, JSON.stringify(await wh.json()).slice(0,300));
  
  const ts = await fetch(`${url}/rest/v1/topic_subscriptions?select=id,topic,status&limit=10`, { headers: h });
  console.log('topic_subscriptions:', ts.status, JSON.stringify(await ts.json()).slice(0,300));
}
run();
