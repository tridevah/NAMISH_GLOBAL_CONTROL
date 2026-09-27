import fs from 'fs'

const commonMetadata = {
    'NAMISH_BG': { business_name: 'BAGS', short_name: 'Bag' },
    'NAMISH_BO': { business_name: 'BOTTLES', short_name: 'Btl' },
    'NAMISH_BX': { business_name: 'BOX', short_name: 'Box' },
    'NAMISH_BE': { business_name: 'BUNDLES', short_name: 'Bdl' },
    'NAMISH_CA': { business_name: 'CANS', short_name: 'Can' },
    'NAMISH_CT': { business_name: 'CARTONS', short_name: 'Ctn' },
    'UNECE_REC20_MTQ': { business_name: 'CUBIC METER', short_name: 'Cbm' },
    'UNECE_REC20_DAY': { business_name: 'DAY', short_name: 'Day' },
    'UNECE_REC20_DZN': { business_name: 'DOZENS', short_name: 'Dzn' },
    'UNECE_REC20_GRM': { business_name: 'GRAMMES', short_name: 'Gm' },
    'UNECE_REC20_MGM': { business_name: 'MILLIGRAM', short_name: 'mg' },
    'UNECE_REC20_HUR': { business_name: 'HOUR', short_name: 'Hr' },
    'UNECE_REC20_KGM': { business_name: 'KILOGRAMS', short_name: 'Kg' },
    'UNECE_REC20_KMT': { business_name: 'KILOMETER', short_name: 'Km' },
    'UNECE_REC20_LTR': { business_name: 'LITRE', short_name: 'Ltr' },
    'UNECE_REC20_MTR': { business_name: 'METERS', short_name: 'Mtr' },
    'UNECE_REC20_MLT': { business_name: 'MILLILITRE', short_name: 'Ml' },
    'UNECE_REC20_C62': { business_name: 'NUMBERS', short_name: 'Nos' },
    'NAMISH_PK': { business_name: 'PACKS', short_name: 'Pac' },
    'UNECE_REC20_PR': { business_name: 'PAIRS', short_name: 'Prs' },
    'UNECE_REC20_H87': { business_name: 'PIECES', short_name: 'Pcs' },
    'UNECE_REC20_DTN': { business_name: 'QUINTAL', short_name: 'Qtl' },
    'NAMISH_RO': { business_name: 'ROLLS', short_name: 'Rol' },
    'UNECE_REC20_E48': { business_name: 'SERVICE', short_name: 'Ser' },
    'UNECE_REC20_SET': { business_name: 'SET', short_name: 'Set' },
    'UNECE_REC20_FTK': { business_name: 'SQUARE FEET', short_name: 'Sqf' },
    'UNECE_REC20_MTK': { business_name: 'SQUARE METERS', short_name: 'Sqm' },
    'UNECE_REC20_U2': { business_name: 'TABLETS', short_name: 'Tbs' },
    'UNECE_REC20_TNE': { business_name: 'TON / METRIC TON', short_name: 'Ton' },
    'UNECE_REC20_EA': { business_name: 'UNIT', short_name: 'Unit' }
}

const routeCode = `import { NextRequest, NextResponse } from 'next/server'
import { createAdminClient } from '@/utils/supabase/admin'
import { getAuthContext } from '@/utils/auth'

const HARDCODED_METADATA = ${JSON.stringify(commonMetadata)};

export async function GET(req: NextRequest) {
    try {
        const { staff } = await getAuthContext()
        if (!staff) return NextResponse.json({ error: 'Unauthorized Access: Staff permissions required' }, { status: 403 })

        const { searchParams } = new URL(req.url)
        const limit = parseInt(searchParams.get('limit') || '100')
        const offset = parseInt(searchParams.get('offset') || '0')
        const search = searchParams.get('search')?.toLowerCase() || ''
        const status = searchParams.get('status')
        const isBusiness = searchParams.get('is_business') === 'true'

        const admin = createAdminClient()
        
        const buildQuery = (selectCols: string) => {
            let q = admin.from('measurement_units').select(selectCols, { count: 'exact' })
            if (search) {
                if (selectCols.includes('business_name')) {
                    q = q.or(\`name.ilike.%\${search}%,canonical_code.ilike.%\${search}%,standard_code.ilike.%\${search}%,symbol.ilike.%\${search}%,business_name.ilike.%\${search}%,short_name.ilike.%\${search}%\`)
                } else {
                    q = q.or(\`name.ilike.%\${search}%,canonical_code.ilike.%\${search}%,standard_code.ilike.%\${search}%,symbol.ilike.%\${search}%\`)
                }
            }
            if (status && status !== 'ALL') q = q.eq('status', status)
            if (isBusiness && selectCols.includes('is_business')) q = q.eq('is_business', true)
            
            return q.order('name', { ascending: true }).range(offset, offset + limit - 1)
        }

        let { data, count, error } = await buildQuery('id, canonical_code, standard_code, name, symbol, category, aliases, status, source, source_version, business_name, short_name, is_business')
        
        // Fallback if migration is unapplied
        if (error && (error.code === 'PGRST200' || error?.message?.includes('Could not find') || error?.code === 'PGRST204' || error?.code === '42703')) {
            const fallback = await buildQuery('id, canonical_code, standard_code, name, symbol, category, aliases, status, source, source_version')
            let fallbackData = fallback.data || []
            
            // Inject hardcoded metadata for display if missing
            fallbackData = fallbackData.map((u: any) => {
                const meta = (HARDCODED_METADATA as any)[u.canonical_code]
                if (meta) return { ...u, ...meta, is_business: true }
                return { ...u, is_business: false }
            })

            // In-memory filter for is_business if requested and unapplied
            if (isBusiness) {
                fallbackData = fallbackData.filter((u: any) => u.is_business)
            }
            
            // In-memory filter for search if using short_name / business_name
            if (search) {
                fallbackData = fallbackData.filter((u: any) => 
                    (u.business_name && u.business_name.toLowerCase().includes(search)) || 
                    (u.short_name && u.short_name.toLowerCase().includes(search)) ||
                    (u.name && u.name.toLowerCase().includes(search)) ||
                    (u.canonical_code && u.canonical_code.toLowerCase().includes(search))
                )
            }

            // Simple client-side pagination for fallback
            count = isBusiness || search ? fallbackData.length : (fallback.count || 0)
            data = isBusiness || search ? fallbackData.slice(offset, offset + limit) : fallbackData
            error = fallback.error
        }

        if (error) {
            console.error('[API] /data-hub/units DB Error:', error)
            return NextResponse.json({ error: 'Service temporarily unavailable. Please verify pending migrations.' }, { status: 503 })
        }

        return NextResponse.json({ data, count })
    } catch (err: any) {
        console.error('[API] /data-hub/units Unexpected Error:', err)
        return NextResponse.json({ error: 'An unexpected error occurred.' }, { status: 500 })
    }
}

export async function POST(req: NextRequest) {
    try {
        const { staff } = await getAuthContext()
        if (!staff) return NextResponse.json({ error: 'Unauthorized Access' }, { status: 403 })

        const body = await req.json()
        const { business_name, short_name, aliases, canonical_code, name } = body

        if (!business_name || !short_name) return NextResponse.json({ error: 'Missing required fields' }, { status: 400 })

        const newCanonicalCode = canonical_code || \`NAMISH_\${short_name.toUpperCase()}\`
        
        const admin = createAdminClient()
        // Attempt insert. If columns don't exist yet, this will fail. That's fine as it's a GC action.
        const { data, error } = await admin
            .from('measurement_units')
            .insert({ 
                canonical_code: newCanonicalCode, 
                standard_code: short_name.toUpperCase().substring(0,3), 
                name: name || business_name.toLowerCase(), 
                category: 'Business', 
                status: 'ACTIVE', 
                source: 'NAMISH_INTERNAL', 
                source_version: '1.0',
                business_name,
                short_name,
                is_business: true,
                aliases: aliases || []
            })
            .select()
            .single()

        if (error) throw error

        return NextResponse.json(data)
    } catch (err: any) {
        console.error('[API] /data-hub/units POST Error:', err)
        if (err.code === '42703' || err.message?.includes('Could not find')) {
            return NextResponse.json({ error: 'Database migration required before adding new business units.' }, { status: 503 })
        }
        return NextResponse.json({ error: 'Failed to create business unit.' }, { status: 500 })
    }
}

export async function PATCH(req: NextRequest) {
    try {
        const { staff } = await getAuthContext()
        if (!staff) return NextResponse.json({ error: 'Unauthorized Access' }, { status: 403 })

        const body = await req.json()
        const { id, is_business, business_name, short_name, aliases, status } = body

        if (!id) return NextResponse.json({ error: 'Missing unit ID' }, { status: 400 })

        const updateData: any = {}
        if (is_business !== undefined) updateData.is_business = is_business
        if (business_name !== undefined) updateData.business_name = business_name
        if (short_name !== undefined) updateData.short_name = short_name
        if (aliases !== undefined) updateData.aliases = aliases
        if (status !== undefined) updateData.status = status

        const admin = createAdminClient()
        const { data, error } = await admin
            .from('measurement_units')
            .update(updateData)
            .eq('id', id)
            .select()
            .single()

        if (error) throw error

        return NextResponse.json(data)
    } catch (err: any) {
        console.error('[API] /data-hub/units PATCH Error:', err)
        if (err.code === '42703' || err.message?.includes('Could not find')) {
            return NextResponse.json({ error: 'Database migration required before updating business unit metadata.' }, { status: 503 })
        }
        return NextResponse.json({ error: 'Failed to update unit metadata.' }, { status: 500 })
    }
}
`
fs.writeFileSync('src/app/api/data-hub/units/route.ts', routeCode)
