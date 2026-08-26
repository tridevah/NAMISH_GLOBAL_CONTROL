import { cache } from 'react'
import { createClient } from '@/utils/supabase/server'
import { createAdminClient } from '@/utils/supabase/admin'
import { redirect } from 'next/navigation'

export const getAuthContext = cache(async () => {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) {
    return { user: null, staff: null, error: 'NO_USER' }
  }

  const adminSupabase = createAdminClient()
  const { data: staff, error: rpcError } = await adminSupabase.rpc('resolve_platform_staff_authority', {
    p_auth_user_id: user.id
  })

  if (rpcError || !staff || staff.status !== 'ACTIVE') {
    return { user, staff: null, error: 'UNAUTHORIZED' }
  }

  return { user, staff, error: null }
})
