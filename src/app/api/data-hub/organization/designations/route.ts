import { NextRequest, NextResponse } from 'next/server'
import { createAdminClient } from '@/utils/supabase/admin'
import { getAuthContext } from '@/utils/auth'

const ALLOWED_MUTATION_ROLES = ['PLATFORM_SUPERADMIN']

export async function GET(req: NextRequest) {
    try {
        const { user, staff } = await getAuthContext()
        if (!user || !staff) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

        const { searchParams } = new URL(req.url)
        const limit  = Math.min(parseInt(searchParams.get('limit')  || '100'), 500)
        const offset = Math.max(parseInt(searchParams.get('offset') || '0'),   0)
        const search = searchParams.get('search')?.toLowerCase() || ''
        const status = searchParams.get('status')

        const admin = createAdminClient()
        let q = admin.from('designations').select('*', { count: 'exact' })

        if (status && status !== 'ALL') q = q.eq('status', status)
        if (search) {
            q = q.or(`code.ilike.%${search}%,name.ilike.%${search}%`)
        }

        q = q.order('name', { ascending: true }).range(offset, offset + limit - 1)
        const { data, count, error } = await q

        if (error) {
            console.error('[GET] DB Error:', JSON.stringify(error))
            if (error.code === 'PGRST205' || error.code === '42P01') {
                return NextResponse.json({ error: 'Database schema missing. Migration required.' }, { status: 503 })
            }
            return NextResponse.json({ error: 'Database error: ' + error.code }, { status: 500 })
        }
        return NextResponse.json({ data, count })
    } catch (e: any) {
        return NextResponse.json({ error: 'Server error' }, { status: 500 })
    }
}

export async function POST(req: NextRequest) {
    try {
        const { user, staff } = await getAuthContext()
        if (!user || !staff || !ALLOWED_MUTATION_ROLES.includes(staff.role)) {
            return NextResponse.json({ error: 'Forbidden: insufficient permissions' }, { status: 403 })
        }
        const body = await req.json()
        if (!body.code || !body.name) return NextResponse.json({ error: 'Missing required fields' }, { status: 400 })
        
        const admin = createAdminClient()
        const { data, error } = await admin.rpc('rpc_create_designation', {
            p_code: body.code.toUpperCase(),
            p_name: body.name,
            p_title_mode: body.title_mode || 'FIXED',
            p_title_template: body.title_template || null,
            p_desc: body.description || null,
            p_status: body.status || 'ACTIVE',
            p_actor: user.id
        })

        if (error) {
            if (error.code === 'P0002') return NextResponse.json({ error: 'Designation not found' }, { status: 404 });
            if (error.code === '23505' && (error.message?.includes('uq_designations_code') || error.details?.includes('uq_designations_code'))) {
                return NextResponse.json({ error: 'Code already exists' }, { status: 409 })
            }
            console.error('[dept/POST] RPC error:', error)
            return NextResponse.json({ error: 'Failed to create designation.' }, { status: 500 })
        }
        return NextResponse.json({ data })
    } catch (e: any) {
        return NextResponse.json({ error: 'An unexpected error occurred.' }, { status: 500 })
    }
}

export async function PATCH(req: NextRequest) {
    try {
        const { user, staff } = await getAuthContext()
        if (!user || !staff || !ALLOWED_MUTATION_ROLES.includes(staff.role)) {
            return NextResponse.json({ error: 'Forbidden: insufficient permissions' }, { status: 403 })
        }
        const body = await req.json()
        if (!body.id) return NextResponse.json({ error: 'Missing ID' }, { status: 400 })
        
        const admin = createAdminClient()
        const { data, error } = await admin.rpc('rpc_update_designation', {
            p_id: body.id,
            p_code: body.code ? body.code.toUpperCase() : null,
            p_name: body.name || null,
            p_title_mode: body.title_mode || null,
            p_title_template: body.title_template !== undefined ? body.title_template : null,
            p_desc: body.description !== undefined ? body.description : null,
            p_status: body.status || null,
            p_actor: user.id
        })

        if (error) {
            if (error.code === '23505' && (error.message?.includes('uq_designations_code') || error.details?.includes('uq_designations_code'))) {
                return NextResponse.json({ error: 'Code already exists' }, { status: 409 })
            }
            console.error('[dept/PATCH] RPC error:', error)
            return NextResponse.json({ error: 'Failed to update designation.' }, { status: 500 })
        }
        return NextResponse.json({ data })
    } catch (e: any) {
        return NextResponse.json({ error: 'An unexpected error occurred.' }, { status: 500 })
    }
}
