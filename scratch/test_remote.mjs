import fs from 'fs';

const env = fs.readFileSync('.env.local', 'utf8');
const SUPABASE_URL = env.match(/NEXT_PUBLIC_SUPABASE_URL=(.*)/)[1].trim();
const SUPABASE_ANON_KEY = env.match(/NEXT_PUBLIC_SUPABASE_ANON_KEY=(.*)/)[1].trim();
const SERVICE_ROLE = env.match(/SUPABASE_SERVICE_ROLE_KEY=(.*)/)[1].trim();

async function run() {
    const res = await fetch(`${SUPABASE_URL}/rest/v1/gst_rate_master?select=id,country_id,rate_percent,rate_name,category,is_current,usage_scope,status,erp_visibility&limit=5`, {
        headers: {
            'apikey': SERVICE_ROLE,
            'Authorization': `Bearer ${SERVICE_ROLE}`
        }
    });
    const data = await res.json();
    console.log(JSON.stringify(data, null, 2));
}

run();
