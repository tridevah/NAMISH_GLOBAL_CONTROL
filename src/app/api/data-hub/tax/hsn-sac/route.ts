import { NextRequest, NextResponse } from 'next/server'
import { createAdminClient } from '@/utils/supabase/admin'
import { getAuthContext } from '@/utils/auth'

export async function GET(req: NextRequest) {
    const { staff } = await getAuthContext()
    if (!staff) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

    const { searchParams } = new URL(req.url)
    const codeType        = searchParams.get('code_type')       // HSN | SAC
    const goodsOrService  = searchParams.get('goods_or_service')// GOODS | SERVICE
    const chapter         = searchParams.get('chapter')          // e.g. '01', '85'
    const status          = searchParams.get('status')           // ACTIVE | INACTIVE
    const search          = searchParams.get('search')           // text search on code + description
    const country       = searchParams.get('country')
    const limit         = Math.min(parseInt(searchParams.get('limit') || '100'), 200)
    const offset        = parseInt(searchParams.get('offset') || '0')

    const admin = createAdminClient()
    let query = admin
        .from('hsn_sac')
        .select('id, country_id, code, code_type, description, chapter, heading, parent_code, goods_or_service, status, effective_from, effective_to, official_source, source_reference', { count: 'exact' })
        .order('code_type', { ascending: true })
        .order('code',      { ascending: true })

    if (country)        query = query.eq('country_id', country)
    if (codeType)       query = query.eq('code_type', codeType)
    if (goodsOrService) query = query.eq('goods_or_service', goodsOrService)
    if (chapter)        query = query.eq('chapter', chapter)
    if (status)         query = query.eq('status', status)
    else                query = query.in('status', ['ACTIVE', 'TOP_LEVEL_CLASSIFICATION_ONLY']) // default: active and top-level
    if (search)         query = query.or(`code.ilike.%${search}%,description.ilike.%${search}%`)

    query = query.range(offset, offset + limit - 1)

    const { data, error, count } = await query
    if (error) return NextResponse.json({ error: error.message }, { status: 500 })

    return NextResponse.json({ data: data || [], total: count ?? 0, limit, offset })
}
