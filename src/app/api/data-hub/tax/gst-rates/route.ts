import { NextRequest, NextResponse } from 'next/server'
import { createAdminClient } from '@/utils/supabase/admin'
import { getAuthContext } from '@/utils/auth'

export async function GET(req: NextRequest) {
    const { staff } = await getAuthContext()
    if (!staff) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

    const { searchParams } = new URL(req.url)
    const category     = searchParams.get('category')    // STANDARD, NIL, COMPOSITION, SPECIAL, etc.
    const usageScope   = searchParams.get('usage_scope') // TRANSACTION_RATE | TAXPAYER_SCHEME | HISTORICAL
    const erpVis       = searchParams.get('erp_visibility') // GENERAL | CONTEXT_ONLY | NEVER_LINE_ITEM | HIDDEN
    const current      = searchParams.get('current')     // 'true' | 'false'
    const search       = searchParams.get('search')      // text search on rate_name/notes
    const country      = searchParams.get('country')
    const limit        = Math.min(parseInt(searchParams.get('limit') || '100'), 500)
    const offset       = parseInt(searchParams.get('offset') || '0')

    const admin = createAdminClient()
    let query = admin
        .from('gst_rate_master')
        .select(
            'id, country_id, rate_percent, rate_name, category, is_current, status,' +
            ' notification_number, notification_date, official_source, source_reference, notes,' +
            ' effective_from, effective_to, created_at,' +
            ' rate_code, usage_scope, erp_visibility, statutory_rate_percent,' +
            ' effective_display_percent, valuation_basis, itc_policy, conditions',
            { count: 'exact' }
        )
        .order('rate_percent', { ascending: true })
        .order('category',     { ascending: true })

    // Default: exclude TAXPAYER_SCHEME and HISTORICAL unless explicitly requested
    if (usageScope) {
        query = query.eq('usage_scope', usageScope)
    } else if (!category || category !== 'COMPOSITION') {
        // Default transaction view: only TRANSACTION_RATE rows
        query = query.eq('usage_scope', 'TRANSACTION_RATE')
    }

    if (country)    query = query.eq('country_id', country)
    if (category)   query = query.eq('category', category)
    if (erpVis)     query = query.eq('erp_visibility', erpVis)
    if (current === 'true')  query = query.eq('is_current', true)
    if (current === 'false') query = query.eq('is_current', false)
    if (search)  query = query.or(`rate_name.ilike.%${search}%,notes.ilike.%${search}%`)

    query = query.range(offset, offset + limit - 1)

    const { data, error, count } = await query
    if (error) return NextResponse.json({ error: error.message }, { status: 500 })

    return NextResponse.json({ data: data || [], total: count ?? 0, limit, offset })
}
