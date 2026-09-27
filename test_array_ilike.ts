import { createAdminClient } from './src/utils/supabase/admin'

async function run() {
    const admin = createAdminClient()
    const { data, error } = await admin.from('measurement_units').select('id, name, aliases').or(`aliases.ilike.%kgs%`).limit(5)
    console.log('DATA:', data)
    console.log('ERROR:', error)
}
run()
