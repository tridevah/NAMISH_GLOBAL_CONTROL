import { NextResponse } from 'next/server'
import { createAdminClient } from '@/utils/supabase/admin'
import { getAuthContext } from '@/utils/auth'

export async function GET() {
  try {
    const { staff } = await getAuthContext()
    if (!staff) return NextResponse.json([], { status: 401 })

    const adminSupabase = createAdminClient()
    const { data, error } = await adminSupabase.rpc('rpc_get_countries')
    
    if (error) {
      console.error('Countries API Error:', error)
      return NextResponse.json([], { status: 500 })
    }
    
    return NextResponse.json(data || [])
  } catch (err) {
    console.error('Countries API Error:', err)
    return NextResponse.json([], { status: 500 })
  }
}
