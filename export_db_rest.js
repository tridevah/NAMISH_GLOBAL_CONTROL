const fs = require('fs');

async function exportData() {
    const envData = fs.readFileSync('.env.local', 'utf8');
    const url = envData.match(/NEXT_PUBLIC_SUPABASE_URL=(.*)/)[1].trim();
    const key = envData.match(/SUPABASE_SERVICE_ROLE_KEY=(.*)/)[1].trim();
    
    // First get India ID
    const res = await fetch(`${url}/rest/v1/countries?iso2=eq.IN&select=id`, {
        headers: { 'apikey': key, 'Authorization': `Bearer ${key}` }
    });
    const countryData = await res.json();
    const indiaId = countryData[0].id;
    
    // Fetch HSN
    const hsnRes = await fetch(`${url}/rest/v1/hsn_sac?code_type=eq.HSN&country_id=eq.${indiaId}&status=eq.ACTIVE&select=code_type,code,description,parent_code,classification_level`, {
        headers: { 'apikey': key, 'Authorization': `Bearer ${key}` }
    });
    const hsnData = await hsnRes.json();
    fs.writeFileSync('db_hsn_export.json', JSON.stringify(hsnData, null, 2), 'utf8');
    console.log('HSN rows:', hsnData.length);
    
    // Fetch SAC
    const sacRes = await fetch(`${url}/rest/v1/hsn_sac?code_type=eq.SAC&country_id=eq.${indiaId}&status=eq.ACTIVE&select=code_type,code,description,parent_code,classification_level`, {
        headers: { 'apikey': key, 'Authorization': `Bearer ${key}` }
    });
    const sacData = await sacRes.json();
    fs.writeFileSync('db_sac_export.json', JSON.stringify(sacData, null, 2), 'utf8');
    console.log('SAC rows:', sacData.length);
}

exportData().catch(console.error);
