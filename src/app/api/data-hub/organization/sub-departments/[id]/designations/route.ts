import { NextRequest, NextResponse } from 'next/server'
import { createAdminClient } from '@/utils/supabase/admin'
import { getAuthContext } from '@/utils/auth'

const ALLOWED_MUTATION_ROLES = ['PLATFORM_SUPERADMIN']

const isUuid = (str: any): boolean => {
    return typeof str === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(str)
}

export async function GET(req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
    try {
        const { user, staff } = await getAuthContext()
        if (!user || !staff) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

        const { id: subDeptId } = await params
        if (!isUuid(subDeptId)) return NextResponse.json({ error: 'Invalid sub-department ID' }, { status: 400 })

        const admin = createAdminClient()
        let allData: any[] = []
        let hasMore = true
        let currentOffset = 0
        const limit = 1000

        while (hasMore) {
            const { data, error } = await admin
                .from('sub_department_designations')
                .select('*')
                .eq('sub_department_id', subDeptId)
                .order('id', { ascending: true })
                .range(currentOffset, currentOffset + limit - 1)
                
            if (error) throw new Error(error.message)
            
            const items = data || []
            allData = allData.concat(items)
            
            if (items.length < limit) {
                hasMore = false
            } else {
                currentOffset += limit
            }
        }

        return NextResponse.json({ data: allData })
    } catch (e: any) {
        return NextResponse.json({ error: e.message || 'Server error' }, { status: 500 })
    }
}

export async function PATCH(req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
    try {
        const { user, staff } = await getAuthContext()
        if (!user || !staff) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
        if (!ALLOWED_MUTATION_ROLES.includes(staff.role || '')) {
            return NextResponse.json({ error: 'Forbidden. Requires PLATFORM_SUPERADMIN.' }, { status: 403 })
        }

        const { id: subDeptId } = await params
        if (!isUuid(subDeptId)) return NextResponse.json({ error: 'Invalid sub-department ID' }, { status: 400 })

        let body
        try {
            body = await req.json()
        } catch (e) {
            return NextResponse.json({ error: 'Invalid JSON body' }, { status: 400 })
        }

        if (typeof body !== 'object' || body === null || Array.isArray(body)) {
            return NextResponse.json({ error: 'Request body must be a JSON object' }, { status: 400 })
        }

        const { add_ids = [], remove_ids = [] } = body

        if (!Array.isArray(add_ids) || !Array.isArray(remove_ids)) {
            return NextResponse.json({ error: 'add_ids and remove_ids must be arrays' }, { status: 400 })
        }
        
        if (add_ids.some(id => typeof id !== 'string') || remove_ids.some(id => typeof id !== 'string')) {
            return NextResponse.json({ error: 'Array elements must be strings' }, { status: 400 })
        }

        if (!add_ids.every(isUuid) || !remove_ids.every(isUuid)) {
            return NextResponse.json({ error: 'All IDs must be valid UUIDs' }, { status: 400 })
        }
        
        const normalizedAdd = add_ids.map(id => id.toLowerCase())
        const normalizedRemove = remove_ids.map(id => id.toLowerCase())

        const addSet = new Set(normalizedAdd)
        const removeSet = new Set(normalizedRemove)
        
        if (addSet.size !== normalizedAdd.length || removeSet.size !== normalizedRemove.length) {
            return NextResponse.json({ error: 'Duplicate IDs are not allowed in the arrays' }, { status: 400 })
        }
        
        const overlap = [...addSet].some(id => removeSet.has(id))
        if (overlap) {
            return NextResponse.json({ error: 'Cannot add and remove the same designation simultaneously' }, { status: 400 })
        }

        const admin = createAdminClient()
        const { error } = await admin.rpc('rpc_update_sub_dept_designations', {
            p_sub_dept_id: subDeptId,
            p_add_ids: normalizedAdd,
            p_remove_ids: normalizedRemove,
            p_actor: user.id
        })

        if (error) {
            if (error.code === '22004' || error.code === '2202E') {
                return NextResponse.json({ error: error.message }, { status: 400 })
            }
            if (error.code === 'P0001') {
                return NextResponse.json({ error: error.message }, { status: 409 })
            }
            if (error.code === 'P0002') {
                return NextResponse.json({ error: error.message }, { status: 404 })
            }
            return NextResponse.json({ error: 'Database error' }, { status: 500 })
        }

        return NextResponse.json({ success: true })
    } catch (e: any) {
        return NextResponse.json({ error: e.message || 'Server error' }, { status: 500 })
    }
}