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
        const { releaseId } = body
        if (!releaseId) return NextResponse.json({ error: 'releaseId required' }, { status: 400 })

        const admin = createAdminClient()
        const { data, error } = await admin.rpc('publish_draft_release', {
            p_release_id: releaseId
        })

        if (error) {
            console.error(error)
            return NextResponse.json({ error: error.message }, { status: 500 })
        }

        return NextResponse.json({ success: data })
    } catch (err: any) {
        return NextResponse.json({ error: err.message }, { status: 500 })
    }
}
