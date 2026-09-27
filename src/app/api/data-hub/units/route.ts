import { NextRequest, NextResponse } from 'next/server'
import { createAdminClient } from '@/utils/supabase/admin'
import { getAuthContext } from '@/utils/auth'

// Allowed mutation role — same policy used across all GC data-hub routes
const ALLOWED_MUTATION_ROLES = ['PLATFORM_SUPERADMIN']

function isUUID(v: string): boolean {
    return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v)
}

function isValidStatus(v: string): boolean {
    return v === 'ACTIVE' || v === 'INACTIVE'
}

// ── GET ──────────────────────────────────────────────────────────────────────

export async function GET(req: NextRequest) {
    try {
        const { user, staff } = await getAuthContext()
        if (!user || !staff) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

        const { searchParams } = new URL(req.url)
        const limit  = Math.min(parseInt(searchParams.get('limit')  || '100'), 500)
        const offset = Math.max(parseInt(searchParams.get('offset') || '0'),   0)
        const search     = searchParams.get('search')?.toLowerCase() || ''
        const status     = searchParams.get('status')
        const isBusiness = searchParams.get('is_business') === 'true'

        const admin = createAdminClient()

        let q = admin
            .from('measurement_units')
            .select(
                'id, canonical_code, standard_code, name, symbol, category, aliases, ' +
                'status, source, source_version, business_name, short_name, is_business',
                { count: 'exact' }
            )

        if (search) {
            q = q.or(
                `name.ilike.%${search}%,` +
                `canonical_code.ilike.%${search}%,` +
                `standard_code.ilike.%${search}%,` +
                `symbol.ilike.%${search}%,` +
                `business_name.ilike.%${search}%,` +
                `short_name.ilike.%${search}%,` +
                `aliases_text.ilike.%${search}%`
            )
        }

        // ENFORCE Business-Unit Scope per requirements
        q = q.eq('is_business', true)

        if (status && status !== 'ALL') q = q.eq('status', status)

        q = q.order('name', { ascending: true }).range(offset, offset + limit - 1)

        const { data, count, error } = await q

        if (error) {
            console.error('[units/GET] DB error:', error)
            if (
                error.code === 'PGRST200' || error.code === 'PGRST204' ||
                error.code === '42703'    || error.message?.includes('Could not find')
            ) {
                return NextResponse.json(
                    { error: 'Database migration pending. Apply rehearsal_000036_units_metadata.sql to enable this view.' },
                    { status: 503 }
                )
            }
            return NextResponse.json({ error: 'Service temporarily unavailable.' }, { status: 503 })
        }

        return NextResponse.json({ data, count })
    } catch (err: any) {
        console.error('[units/GET] Unexpected error:', err)
        return NextResponse.json({ error: 'An unexpected error occurred.' }, { status: 500 })
    }
}

// ── POST ─────────────────────────────────────────────────────────────────────

export async function POST(req: NextRequest) {
    try {
        const { user, staff } = await getAuthContext()
        if (!user || !staff) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
        if (!ALLOWED_MUTATION_ROLES.includes(staff.role)) {
            return NextResponse.json({ error: 'Forbidden: insufficient permissions' }, { status: 403 })
        }

        const body = await req.json()
        const { business_name, short_name, aliases } = body

        // Validate required fields
        const bn = typeof business_name === 'string' ? business_name.trim() : ''
        const sn = typeof short_name    === 'string' ? short_name.trim()    : ''

        if (!bn) return NextResponse.json({ error: 'business_name is required and must be a non-empty string.' }, { status: 400 })
        if (!sn) return NextResponse.json({ error: 'short_name is required and must be a non-empty string.' }, { status: 400 })

        if (aliases !== undefined) {
            if (!Array.isArray(aliases) || aliases.some(a => typeof a !== 'string')) {
                return NextResponse.json({ error: 'aliases must be a string array.' }, { status: 400 })
            }
        }

        // canonical_code is server-generated; never accepted from client
        const admin = createAdminClient()
        const { data, error } = await admin.rpc('rpc_add_business_unit', {
            p_business_name: bn,
            p_short_name:    sn,
            p_aliases:       (aliases as string[] | undefined) || [],
        })

        if (error) {
            console.error('[units/POST] RPC error:', error)
            if (error.code === '42703' || error.code === 'PGRST202' || error.message?.includes('Could not find')) {
                return NextResponse.json({ error: 'Database migration required before adding business units.' }, { status: 503 })
            }
            if (error.code === '23505') {
                return NextResponse.json(
                    { error: 'This business unit already exists.' },
                    { status: 409 }
                )
            }
            return NextResponse.json({ error: 'Failed to create business unit.' }, { status: 500 })
        }

        return NextResponse.json(data, { status: 201 })
    } catch (err: any) {
        console.error('[units/POST] Unexpected error:', err)
        return NextResponse.json({ error: 'An unexpected error occurred.' }, { status: 500 })
    }
}

// ── PATCH ─────────────────────────────────────────────────────────────────────

export async function PATCH(req: NextRequest) {
    try {
        const { user, staff } = await getAuthContext()
        if (!user || !staff) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
        if (!ALLOWED_MUTATION_ROLES.includes(staff.role)) {
            return NextResponse.json({ error: 'Forbidden: insufficient permissions' }, { status: 403 })
        }

        const body = await req.json()
        const { id, business_name, short_name, aliases, status, is_business } = body

        // Validate ID
        if (!id || typeof id !== 'string' || !isUUID(id)) {
            return NextResponse.json({ error: 'id must be a valid UUID.' }, { status: 400 })
        }

        // Validate fields if provided (omitted fields remain unchanged via COALESCE in RPC)
        if (business_name !== undefined) {
            const bn = typeof business_name === 'string' ? business_name.trim() : ''
            if (!bn) return NextResponse.json({ error: 'business_name must be a non-empty string.' }, { status: 400 })
        }
        if (short_name !== undefined) {
            const sn = typeof short_name === 'string' ? short_name.trim() : ''
            if (!sn) return NextResponse.json({ error: 'short_name must be a non-empty string.' }, { status: 400 })
        }
        if (aliases !== undefined) {
            if (!Array.isArray(aliases) || aliases.some(a => typeof a !== 'string')) {
                return NextResponse.json({ error: 'aliases must be a string array.' }, { status: 400 })
            }
        }
        if (status !== undefined && !isValidStatus(status)) {
            return NextResponse.json({ error: 'status must be ACTIVE or INACTIVE.' }, { status: 400 })
        }
        if (is_business !== undefined && typeof is_business !== 'boolean') {
            return NextResponse.json({ error: 'is_business must be a boolean.' }, { status: 400 })
        }

        const admin = createAdminClient()
        const { data, error } = await admin.rpc('rpc_update_business_unit', {
            p_id:            id,
            p_business_name: business_name !== undefined ? (business_name as string).trim() : null,
            p_short_name:    short_name    !== undefined ? (short_name    as string).trim() : null,
            p_aliases:       aliases       !== undefined ? aliases        as string[]        : null,
            p_status:        status        !== undefined ? status         as string          : null,
            p_is_business:   is_business   !== undefined ? is_business    as boolean         : null,
        })

        if (error) {
            console.error('[units/PATCH] RPC error:', error)
            if (error.code === '42703' || error.code === 'PGRST202' || error.message?.includes('Could not find')) {
                return NextResponse.json({ error: 'Database migration required before updating business units.' }, { status: 503 })
            }
            if (error.code === 'P0002') { // RPC raises this on NOT FOUND
                return NextResponse.json({ error: 'Business unit not found.' }, { status: 404 })
            }
            if (error.code === '23505') {
                return NextResponse.json(
                    { error: 'This business unit already exists.' },
                    { status: 409 }
                )
            }
            
            return NextResponse.json({ error: 'Failed to update business unit.' }, { status: 500 })
        }

        if (data === null) {
            // RPC returned NULL — unit existed but was not updated (should not happen with correct RPC)
            return NextResponse.json({ error: 'Business unit not found.' }, { status: 404 })
        }

        return NextResponse.json(data)
    } catch (err: any) {
        console.error('[units/PATCH] Unexpected error:', err)
        return NextResponse.json({ error: 'An unexpected error occurred.' }, { status: 500 })
    }
}
