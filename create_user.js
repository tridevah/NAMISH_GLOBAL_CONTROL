const { createClient } = require('@supabase/supabase-js');
const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
const supabase = createClient(url, key);

(async () => {
  const { data: adminUser, error } = await supabase.auth.admin.createUser({
    email: 'test_admin_gc@tridevah.com',
    password: 'Password123!',
    email_confirm: true,
  });
  if (error) {
    if (error.message.includes('already registered')) console.log('User already exists');
    else console.error('Error creating user:', error);
  } else {
    console.log('Test user created:', adminUser.user.id);
  }
  
  const { data } = await supabase.from('staff_roles').select('*').eq('email', 'test_admin_gc@tridevah.com').single();
  if(!data) {
     const { error: dbError } = await supabase.from('staff_roles').insert({
       role: 'SUPER_ADMIN',
       email: 'test_admin_gc@tridevah.com'
     });
     if (dbError) console.error('Error upserting staff role:', dbError);
     else console.log('Staff role assigned.');
  } else {
     console.log('Staff role already assigned');
  }
})();
