import { NextRequest, NextResponse } from 'next/server'
import { createAdminClient } from '@/utils/supabase/admin'
import { getAuthContext } from '@/utils/auth'

const ALLOWED_MUTATION_ROLES = ['PLATFORM_SUPERADMIN']
const isUuid = (str: string) => /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(str)

export async function GET(req: NextRequest) {
    try {
        const { user, staff } = await getAuthContext()
        if (!user || !staff) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

        const { searchParams } = new URL(req.url)
        const limitRaw = parseInt(searchParams.get('limit') || '100')
        const offsetRaw = parseInt(searchParams.get('offset') || '0')
        const limit  = isNaN(limitRaw) ? 100 : Math.min(Math.max(limitRaw, 1), 500)
        const offset = isNaN(offsetRaw) ? 0 : Math.max(offsetRaw, 0)
        const search = searchParams.get('search')?.toLowerCase() || ''
        const status = searchParams.get('status')
        const department_id = searchParams.get('department_id')

        if (department_id && !isUuid(department_id)) {
            return NextResponse.json({ error: 'Invalid department_id UUID format' }, { status: 400 })
        }

        const admin = createAdminClient()
        let q = admin.from('sub_departments').select('*', { count: 'exact' })

        if (status && status !== 'ALL') {
            if (!['ACTIVE', 'INACTIVE'].includes(status)) return NextResponse.json({ error: 'Invalid status filter' }, { status: 400 })
            q = q.eq('status', status)
        }
        if (department_id) q = q.eq('department_id', department_id)
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
        console.error('API CATCH ERROR:', e);
        return NextResponse.json({ error: 'Server error' }, { status: 500 })
    }
}

export async function POST(req: NextRequest) {
    try {
        const { user, staff } = await getAuthContext()
        if (!user || !staff || !ALLOWED_MUTATION_ROLES.includes(staff.role)) {
            return NextResponse.json({ error: 'Forbidden: insufficient permissions' }, { status: 403 })
        }
        
        let body;
        try {
            body = await req.json()
        } catch (e) {
            return NextResponse.json({ error: 'Malformed JSON' }, { status: 400 })
        }
        
        if (typeof body !== 'object' || body === null) return NextResponse.json({ error: 'Invalid request body' }, { status: 400 })
        
        if (body.status !== undefined && !['ACTIVE', 'INACTIVE'].includes(body.status)) {
            return NextResponse.json({ error: 'Invalid status' }, { status: 400 })
        }
        if (body.title_display_name !== undefined && body.title_display_name !== null && typeof body.title_display_name !== 'string') {
            return NextResponse.json({ error: 'Invalid title_display_name type' }, { status: 400 })
        }
        if (body.description !== undefined && body.description !== null && typeof body.description !== 'string') {
            return NextResponse.json({ error: 'Invalid description type' }, { status: 400 })
        }
        
        const code = typeof body.code === 'string' ? body.code.trim().toUpperCase() : ''
        const name = typeof body.name === 'string' ? body.name.trim() : ''
        const department_id = typeof body.department_id === 'string' ? body.department_id.trim() : ''
        const status = body.status || 'ACTIVE'
        const title_display_name = (typeof body.title_display_name === 'string' && body.title_display_name.trim()) ? body.title_display_name.trim() : null
        const description = (typeof body.description === 'string' && body.description.trim()) ? body.description.trim() : null
        
        if (!code || !name || !department_id) {
            return NextResponse.json({ error: 'Missing or blank required fields: code, name, department_id' }, { status: 400 })
        }
        
        if (!isUuid(department_id)) return NextResponse.json({ error: 'Invalid department_id UUID format' }, { status: 400 })
        
        const admin = createAdminClient()
        const { data, error } = await admin.rpc('rpc_create_sub_department', {
            p_department_id: department_id,
            p_code: code,
            p_name: name,
            p_title_display_name: title_display_name,
            p_desc: description,
            p_status: status,
            p_actor: user.id
        })

        if (error) {
            if (error.code === '23505') {
                return NextResponse.json({ error: 'Code or name already exists in this department' }, { status: 409 })
            }
            if (error.code === 'P0002') return NextResponse.json({ error: 'Parent department not found or inactive' }, { status: 404 });
            console.error('[sub_dept/POST] RPC error:', JSON.stringify(error, null, 2))
            return NextResponse.json({ error: 'Failed to create sub-department.' }, { status: 500 })
        }
        return NextResponse.json({ data })
    } catch (e: any) { 
        console.error('API CATCH ERROR:', e);
        return NextResponse.json({ error: 'An unexpected error occurred.' }, { status: 500 })
    }
}

export async function PATCH(req: NextRequest) {
    try {
        const { user, staff } = await getAuthContext()
        if (!user || !staff || !ALLOWED_MUTATION_ROLES.includes(staff.role)) {
            return NextResponse.json({ error: 'Forbidden: insufficient permissions' }, { status: 403 })
        }
        let body;
        try {
            body = await req.json()
        } catch(e) {
            return NextResponse.json({ error: 'Malformed JSON' }, { status: 400 })
        }
        
        if (typeof body !== 'object' || body === null) return NextResponse.json({ error: 'Invalid request body' }, { status: 400 })
        if (!body.id || !isUuid(body.id)) return NextResponse.json({ error: 'Missing or invalid ID' }, { status: 400 })
        
        if (body.department_id !== undefined && !isUuid(body.department_id)) {
            return NextResponse.json({ error: 'Invalid department_id UUID format' }, { status: 400 })
        }
        if (body.status !== undefined && !['ACTIVE', 'INACTIVE'].includes(body.status)) {
            return NextResponse.json({ error: 'Invalid status' }, { status: 400 })
        }
        if (body.code !== undefined && (typeof body.code !== 'string' || !body.code.trim())) {
             return NextResponse.json({ error: 'Code cannot be blank' }, { status: 400 })
        }
        if (body.name !== undefined && (typeof body.name !== 'string' || !body.name.trim())) {
             return NextResponse.json({ error: 'Name cannot be blank' }, { status: 400 })
        }
        if (body.title_display_name !== undefined && body.title_display_name !== null && typeof body.title_display_name !== 'string') {
            return NextResponse.json({ error: 'Invalid title_display_name type' }, { status: 400 })
        }
        if (body.description !== undefined && body.description !== null && typeof body.description !== 'string') {
            return NextResponse.json({ error: 'Invalid description type' }, { status: 400 })
        }

        const p_update_title = body.title_display_name !== undefined;
        const p_title_val = (typeof body.title_display_name === 'string' && body.title_display_name.trim()) ? body.title_display_name.trim() : null;
        
        const p_update_desc = body.description !== undefined;
        const p_desc_val = (typeof body.description === 'string' && body.description.trim()) ? body.description.trim() : null;

        const admin = createAdminClient()
        const { data, error } = await admin.rpc('rpc_update_sub_department', {
            p_id: body.id,
            p_department_id: body.department_id || null,
            p_code: body.code ? body.code.trim().toUpperCase() : null,
            p_name: body.name ? body.name.trim() : null,
            p_update_title: p_update_title,
            p_title_display_name: p_title_val,
            p_update_desc: p_update_desc,
            p_desc: p_desc_val,
            p_status: body.status || null,
            p_actor: user.id
        })

        if (error) {
            if (error.code === '23505') {
                return NextResponse.json({ error: 'Code or name already exists in this department' }, { status: 409 })
            }
            if (error.code === 'P0002') return NextResponse.json({ error: 'Record not found, invalid parent, or unsafe reassignment' }, { status: 404 })
            if (error.code === 'P0001') return NextResponse.json({ error: error.message }, { status: 409 })
            console.error('[sub_dept/PATCH] RPC error:', JSON.stringify(error, Object.getOwnPropertyNames(error), 2))
            return NextResponse.json({ error: 'Failed to update sub-department.' }, { status: 500 })
        }
        return NextResponse.json({ data })
    } catch (e: any) { 
        console.error('API CATCH ERROR:', e);
        return NextResponse.json({ error: 'An unexpected error occurred.' }, { status: 500 })
    }
}