import { NextRequest, NextResponse } from 'next/server';
import { jwtVerify } from "jose";
import { createAdminClient } from '@/utils/supabase/admin';

export async function GET(req: NextRequest) {
    try {
        const authHeader = req.headers.get("Authorization");
        if (!authHeader || !authHeader.startsWith("Bearer ")) {
            return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
        }

        const token = authHeader.substring(7);
        const secretStr = process.env.GLOBAL_CONTROL_HMAC_SECRET;
        if (!secretStr) {
            console.error("[S2S] GLOBAL_CONTROL_HMAC_SECRET not configured");
            return NextResponse.json({ error: "Service Unavailable" }, { status: 503 });
        }

        const secretKey = new TextEncoder().encode(secretStr);
        let verifiedPayload: Record<string, unknown>;
        try {
            const { payload } = await jwtVerify(token, secretKey, {
                algorithms: ["HS256"],
                issuer: "NAMISH_ERP",
                audience: "NAMISH_GLOBAL_CONTROL",
                maxTokenAge: "1m",
            });
            verifiedPayload = payload as Record<string, unknown>;
        } catch (e) {
            console.error('JWT Verify Error:', e);
            return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
        }

        if (!verifiedPayload.exp || !verifiedPayload.iat) {
            return NextResponse.json({ error: "Invalid Token Claims" }, { status: 401 });
        }

        if (verifiedPayload.action !== "read_master_data") {
            return NextResponse.json({ error: "Forbidden" }, { status: 403 });
        }

        const { searchParams } = new URL(req.url);
        const country = searchParams.get('country');
        const search = searchParams.get('search');
        const id = searchParams.get('id');
        const limit = Math.min(parseInt(searchParams.get('limit') || '100'), 500);
        const offset = parseInt(searchParams.get('offset') || '0');

        const admin = createAdminClient();
        
        let query = admin
            .from('gst_rate_master')
            .select(
                'id, country_id, rate_percent, rate_name, category, is_current, status, effective_from, effective_to, created_at, rate_code, usage_scope, erp_visibility, statutory_rate_percent, effective_display_percent, valuation_basis, itc_policy, conditions',
                { count: 'exact' }
            )
            .order('rate_percent', { ascending: true })
            .order('category', { ascending: true });

        const activeOnly = searchParams.get('active_only') !== 'false';
        const ids = searchParams.get('ids');

        if (activeOnly) {
            query = query
                .eq('usage_scope', 'TRANSACTION_RATE')
                .eq('is_current', true)
                .eq('status', 'ACTIVE')
                .in('erp_visibility', ['GENERAL', 'CONTEXT_ONLY']);
        }

        if (country) {
            query = query.eq('country_id', country);
        }

        if (id) {
            query = query.eq('id', id);
        }

        if (ids) {
            const idArray = ids.split(',').map(i => i.trim()).filter(Boolean);
            if (idArray.length > 0) {
                query = query.in('id', idArray);
            }
        }

        if (search) {
            query = query.or(`rate_name.ilike.%${search}%,notes.ilike.%${search}%`);
        }

        query = query.range(offset, offset + limit - 1);

        const { data, error, count } = await query;

        if (error) {
            console.error('[S2S Taxes] DB Error:', error);
            return NextResponse.json({ error: 'Database Error' }, { status: 500 });
        }

        return NextResponse.json({ rows: data || [], total: count || 0 });

    } catch (err: any) {
        console.error('[S2S Taxes] Internal Error:', err);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
