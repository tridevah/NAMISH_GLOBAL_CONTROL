import { NextRequest, NextResponse } from 'next/server'
import { createAdminClient } from '@/utils/supabase/admin'
import { getAuthContext } from '@/utils/auth'

const isUuid = (str: any): boolean => {
    return typeof str === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(str)
}

export async function GET(req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
    try {
        const { user, staff } = await getAuthContext()
        if (!user || !staff) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

        const { id: deptId } = await params
        if (!isUuid(deptId)) return NextResponse.json({ error: 'Invalid department ID' }, { status: 400 })

        const admin = createAdminClient()
        let allData: any[] = []
        let hasMore = true
        let currentOffset = 0
        const limit = 1000

        while (hasMore) {
            const { data, error } = await admin
                .from('department_designations')
                .select('*')
                .eq('department_id', deptId)
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