import { User } from '@supabase/supabase-js'

export async function getAuthContext() {
  return {
    user: { id: 'test', email: 'test@tridevah.com' } as User,
    staff: { role: 'PLATFORM_SUPERADMIN', status: 'ACTIVE', id: 'test' } as any,
    error: null,
  }
}
