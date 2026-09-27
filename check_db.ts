import { createAdminClient } from './src/utils/supabase/admin'

async function check() {
    const admin = createAdminClient()
    const { data, error } = await admin.from('measurement_units').select('id, canonical_code, standard_code, name, symbol, category, aliases, status, source, source_version, business_name, short_name, is_common', { count: 'exact' }).limit(1)
    
    if (error) {
        console.error('ERROR:', error)
    } else {
        console.log('SUCCESS:', data)
    }
}
check()
