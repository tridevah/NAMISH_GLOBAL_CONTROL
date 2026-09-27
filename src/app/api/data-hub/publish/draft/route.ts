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
        const { version, include_cleanup } = body

        if (!version) return NextResponse.json({ error: 'version required' }, { status: 400 })

        const admin = createAdminClient()
        
        // Idempotency / Safe retry check
        const { data: existing } = await admin.from('catalog_releases').select('id').eq('version', version).single()
        if (existing) {
            return NextResponse.json({ error: `Release version ${version} already exists. Please choose a different version.` }, { status: 409 })
        }

        const { data: releaseId, error } = await admin.rpc('create_business_release_wrapper', {
            p_version: version,
            p_include_cleanup: !!include_cleanup
        })

        if (error) {
            console.error(error)
            return NextResponse.json({ error: error.message }, { status: 500 })
        }

        return NextResponse.json({ releaseId })
    } catch (err: any) {
        return NextResponse.json({ error: err.message }, { status: 500 })
    }
}

export async function GET(req: NextRequest) {
    try {
        const { user, staff } = await getAuthContext()
        if (!user || !staff) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
        if (!ALLOWED_MUTATION_ROLES.includes(staff.role)) {
            return NextResponse.json({ error: 'Forbidden: insufficient permissions' }, { status: 403 })
        }

        const id = req.nextUrl.searchParams.get('id')
        if (!id) return NextResponse.json({ error: 'id required' }, { status: 400 })

        const admin = createAdminClient()
        const { data: review, error: reviewErr } = await admin.rpc('get_release_review', { p_draft_id: id })

        if (reviewErr) return NextResponse.json({ error: reviewErr.message }, { status: 500 })
        if (review.error) return NextResponse.json({ error: review.error }, { status: 404 })

        return NextResponse.json(review)
    } catch (err: any) {
        return NextResponse.json({ error: err.message }, { status: 500 })
    }
}
