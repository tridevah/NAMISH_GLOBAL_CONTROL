import { NextRequest, NextResponse } from 'next/server'
import { getAuthContext } from '@/utils/auth'
import { createAdminClient } from '@/utils/supabase/admin'

const ALLOWED_MUTATION_ROLES = ['PLATFORM_SUPERADMIN']

export async function POST(req: NextRequest) {
    try {
        const { user, staff } = await getAuthContext()
        if (!user || !staff) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

        if (!ALLOWED_MUTATION_ROLES.includes(staff.role)) {
            return NextResponse.json({ error: 'Forbidden: insufficient permissions' }, { status: 403 })
        }

        const body = await req.json()
        const { releaseId } = body
        if (!releaseId) return NextResponse.json({ error: 'releaseId required' }, { status: 400 })

        const admin = createAdminClient()
        const { data, error } = await admin.rpc('publish_draft_release_wrapper', {
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
