import { NextResponse } from 'next/server'
import { createAdminClient } from '@/utils/supabase/admin'
import { getAuthContext } from '@/utils/auth'

export async function GET() {
  try {
    const { staff } = await getAuthContext()
    if (!staff) return NextResponse.json([], { status: 401 })

    const adminSupabase = createAdminClient()

    // Fetch countries via RPC
    const { data: countries, error: countriesError } = await adminSupabase.rpc('rpc_get_countries')
    if (countriesError) {
      console.error('Countries API Error:', countriesError)
      return NextResponse.json([], { status: 500 })
    }

    // Fetch all tax coverage statuses in one query
    const { data: coverages } = await adminSupabase
      .from('country_tax_coverage')
      .select('country_id, status')

    // Build lookup map: country_id → coverage status
    const coverageMap: Record<string, string> = {}
    for (const c of coverages ?? []) {
      coverageMap[c.country_id] = c.status
    }

    // Merge tax_coverage_status onto each country row
    const merged = (countries ?? []).map((country: any) => ({
      ...country,
      tax_coverage_status: coverageMap[country.id] ?? 'NOT_CONFIGURED',
    }))

    return NextResponse.json(merged)
  } catch (err) {
    console.error('Countries API Error:', err)
    return NextResponse.json([], { status: 500 })
  }
}
