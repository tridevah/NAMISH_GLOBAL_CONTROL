const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;

async function verify() {
  console.log('1. Active UI Supabase host: ' + new URL(url).hostname);
  
  // Auth users check
  const resUsers = await fetch(url + '/auth/v1/admin/users', {
      headers: { 'apikey': key, 'Authorization': 'Bearer ' + key }
  });
  if (!resUsers.ok) {
    console.error('Error fetching users:', resUsers.status, await resUsers.text());
  } else {
    const { users } = await resUsers.json();
    const admin = users.find(u => u.email === 'admin@tridevah.com');
    if (admin) {
      console.log('2. admin@tridevah.com auth check: Found (ID: ' + admin.id + ', Role: ' + admin.role + ')');
    } else {
      console.log('2. admin@tridevah.com auth check: NOT FOUND');
    }
  }

  const resLevels = await fetch(url + '/rest/v1/geography_levels?select=id,level_key', {
      headers: { 'apikey': key, 'Authorization': 'Bearer ' + key, 'Accept-Profile': 'catalog' }
  });
  const levels = await resLevels.json();
  
  console.log('3. Existing remote Geography counts:');
  for (const lvl of levels) {
      const resCount = await fetch(url + '/rest/v1/geography_units?geography_level_id=eq.' + lvl.id + '&select=*', {
          method: 'HEAD',
          headers: { 'apikey': key, 'Authorization': 'Bearer ' + key, 'Accept-Profile': 'catalog', 'Prefer': 'count=exact' }
      });
      const count = resCount.headers.get('content-range')?.split('/')[1] || 0;
      console.log('   - ' + lvl.level_key + ': ' + count);
  }

  const resBlocks = await fetch(url + '/rest/v1/development_blocks?select=*', {
      method: 'HEAD',
      headers: { 'apikey': key, 'Authorization': 'Bearer ' + key, 'Accept-Profile': 'catalog', 'Prefer': 'count=exact' }
  });
  console.log('   - development_blocks: ' + (resBlocks.headers.get('content-range')?.split('/')[1] || 0));

  const resBlockDist = await fetch(url + '/rest/v1/block_districts?select=*', {
      method: 'HEAD',
      headers: { 'apikey': key, 'Authorization': 'Bearer ' + key, 'Accept-Profile': 'catalog', 'Prefer': 'count=exact' }
  });
  console.log('   - block_districts: ' + (resBlockDist.headers.get('content-range')?.split('/')[1] || 0));

  // For data_imports.releases
  const resRel = await fetch(url + '/rest/v1/releases?id=eq.5fac63d7-0101-43c5-8867-bd75ff609861', {
      headers: { 'apikey': key, 'Authorization': 'Bearer ' + key, 'Accept-Profile': 'data_imports' }
  });
  const relData = await resRel.json();
  if (relData && relData.length > 0) {
      console.log('4. R16 data presence: FOUND (' + relData[0].release_name + ', Status: ' + relData[0].status + ')');
  } else {
      console.log('4. R16 data presence: NOT FOUND IN REMOTE DATABASE');
  }
}
verify();
