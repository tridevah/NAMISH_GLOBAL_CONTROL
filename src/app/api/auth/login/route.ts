import { NextResponse } from 'next/server'
import { createClient } from '@/utils/supabase/server'
import { createAdminClient } from '@/utils/supabase/admin'

export async function POST(req: Request) {
  try {
    const { email, password } = await req.json()
    
    // Auth the user and let SSR client handle cookie injection securely via Set-Cookie
    const supabase = await createClient()
    const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
      email,
      password,
    })

    if (authError || !authData.user) {
      return NextResponse.json({ error: authError?.message || 'Invalid login credentials' }, { status: 401 })
    }

    const userId = authData.user.id

    // Derive authority from the backend via service role, never trusting the client
    const adminSupabase = createAdminClient()
    const { data: staff, error: rpcError } = await adminSupabase.rpc('resolve_platform_staff_authority', {
      p_auth_user_id: userId
    })

    if (rpcError || !staff) {
      await supabase.auth.signOut()
      return NextResponse.json({ error: 'Unauthorized: No active platform staff record found.' }, { status: 403 })
    }

    if (staff.status !== 'ACTIVE') {
      await supabase.auth.signOut()
      return NextResponse.json({ error: 'Unauthorized: Staff account is inactive.' }, { status: 403 })
    }

    return NextResponse.json({ success: true, role: staff.role })
  } catch (err: any) {
    return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 })
  }
}
