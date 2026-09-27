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
        const { data: release, error: releaseErr } = await admin
            .from('catalog_releases')
            .select('*')
            .eq('id', id)
            .single()

        if (releaseErr) return NextResponse.json({ error: releaseErr.message }, { status: 500 })

        // Fetch counts for review
        const { data: items } = await admin.from('catalog_release_items')
            .select('item_type')
            .eq('release_id', id)

        const counts = items?.reduce((acc: any, curr: any) => {
            acc[curr.item_type] = (acc[curr.item_type] || 0) + 1
            return acc
        }, {})

        // Check if there's an outbox event (meaning it was published)
        let deliveryStatus = release.status === 'PUBLISHED' ? 'PUBLISHED (Checking outbox...)' : release.status
        
        if (release.status === 'PUBLISHED') {
            const { data: outboxEvent } = await admin.from('outbox_events')
                .select('id, status')
                .eq('topic', 'catalog.release.published')
                .contains('payload', { id }) // The release ID is inside the JSON payload
                .limit(1)
                .single()
            
            if (outboxEvent) {
                deliveryStatus = outboxEvent.status // e.g. PENDING, DELIVERED, FAILED
            }
        }

        // Compare against last PUBLISHED release
        let diffs = null;
        const { data: lastPub } = await admin.from('catalog_releases')
            .select('id')
            .eq('status', 'PUBLISHED')
            .order('created_at', { ascending: false })
            .limit(1)
            .single()

        if (lastPub && lastPub.id) {
             const { data: comparisonData, error: compErr } = await admin.rpc('compare_catalog_releases_wrapper', { 
                 p_pub_id: lastPub.id, 
                 p_draft_id: id 
             })
             if (!compErr) {
                 diffs = comparisonData
             }
        }

        return NextResponse.json({ release, counts, deliveryStatus, diffs })
    } catch (err: any) {
        return NextResponse.json({ error: err.message }, { status: 500 })
    }
}
