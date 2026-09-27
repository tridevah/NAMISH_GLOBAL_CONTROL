import { NextRequest, NextResponse } from 'next/server'
import { createAdminClient } from '@/utils/supabase/admin'
import { getAuthContext } from '@/utils/auth'

// Returns all distinct category codes present in measurement_units.
// Paginates through the complete table (no row-limit truncation) so the
// list is always exhaustive regardless of table size.
export async function GET(_req: NextRequest) {
    try {
        const { staff } = await getAuthContext()
        if (!staff) return NextResponse.json({ error: 'Unauthorized Access: Staff permissions required' }, { status: 403 })

        const admin = createAdminClient()
        const PAGE_SIZE = 1000
        let offset = 0
        const seen = new Set<string>()

        while (true) {
            const { data, error } = await admin
                .from('measurement_units')
                .select('category')
                .order('id')                          // stable deterministic ordering by PK
                .range(offset, offset + PAGE_SIZE - 1)

            if (error) {
                console.error('[API] /data-hub/units/categories DB Error:', error)
                return NextResponse.json({ error: 'Service temporarily unavailable.' }, { status: 503 })
            }
            if (!data || data.length === 0) break

            for (const row of data) {
                if (row.category) seen.add(row.category as string)
            }
            offset += data.length
            if (data.length < PAGE_SIZE) break
        }

        // Return lexicographically sorted list
        const categories = Array.from(seen).sort()
        return NextResponse.json({ categories })
    } catch (err: any) {
        console.error('[API] /data-hub/units/categories Unexpected Error:', err)
        return NextResponse.json({ error: 'An unexpected error occurred.' }, { status: 500 })
    }
}
