const { execSync } = require('child_process');
const crypto = require('crypto');

function hashQuery(q) {
  const res = execSync('npx supabase db query "' + q + '"', {encoding: 'utf8'});
  const match = res.match(/"pg_get_functiondef":\s*"(.*?)"/);
  if (!match) return 'NOT_FOUND';
  const sql = JSON.parse('"' + match[1] + '"').replace(/\r\n/g, '\n').trim();
  return crypto.createHash('sha256').update(sql).digest('hex');
}

const h1 = hashQuery("SELECT pg_get_functiondef(oid) FROM pg_proc WHERE proname = 'rpc_promote_geography_batch' AND pronamespace = 'data_imports'::regnamespace");
const h2 = hashQuery("SELECT pg_get_functiondef(oid) FROM pg_proc WHERE proname = 'rpc_finalize_geography_release' AND pronamespace = 'data_imports'::regnamespace");

console.log('rpc_promote_geography_batch:', h1);
console.log('rpc_finalize_geography_release:', h2);
