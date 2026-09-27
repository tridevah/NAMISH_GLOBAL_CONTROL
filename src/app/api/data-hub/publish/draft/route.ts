import { NextRequest, NextResponse } from 'next/server'
import { getAuthContext } from '@/utils/auth'
import { createAdminClient } from '@/utils/supabase/admin'

export async function POST(req: NextRequest) {
    try {
        const { user, staff } = await getAuthContext()
        if (!user || !staff || staff.role !== 'PLATFORM_ADMIN') {
            return NextResponse.json({ error: 'Unauthorized' }, { status: 403 })
        }

        const body = await req.json()
        const { version, include_cleanup } = body

        if (!version) return NextResponse.json({ error: 'version required' }, { status: 400 })

        const admin = createAdminClient()
        const { data: releaseId, error } = await admin.rpc('create_business_release', {
            p_version: version,
            p_include_cleanup: !!include_cleanup
        })

        if (error) {
            console.error(error)
            return NextResponse.json({ error: error.message }, { status: 500 })
        }

        // Fetch counts for review
        const { data: items } = await admin.from('catalog_release_items')
            .select('item_type')
            .eq('release_id', releaseId)

        const counts = items?.reduce((acc: any, curr: any) => {
            acc[curr.item_type] = (acc[curr.item_type] || 0) + 1
            return acc
        }, {})

        return NextResponse.json({ releaseId, counts })
    } catch (err: any) {
        return NextResponse.json({ error: err.message }, { status: 500 })
    }
}
