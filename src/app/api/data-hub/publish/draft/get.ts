import { NextRequest, NextResponse } from 'next/server'
import { getAuthContext } from '@/utils/auth'
import { createAdminClient } from '@/utils/supabase/admin'

const ALLOWED_MUTATION_ROLES = ['PLATFORM_SUPERADMIN']

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
        let deliveryStatus = 'DRAFT'
        if (release.status === 'PUBLISHED') {
            const { data: outbox } = await admin.from('outbox_events')
                .select('status')
                .eq('topic', 'catalog.release.published')
                .contains('payload', { id }) // The release ID is part of payload
                .order('created_at', { ascending: false })
                .limit(1)
                .single()
            
            if (outbox) {
                deliveryStatus = outbox.status // e.g. PENDING, DELIVERED, FAILED
            } else {
                deliveryStatus = 'PUBLISHED_NO_EVENT'
            }
        }

        return NextResponse.json({ release, counts, deliveryStatus })
    } catch (err: any) {
        return NextResponse.json({ error: err.message }, { status: 500 })
    }
}
