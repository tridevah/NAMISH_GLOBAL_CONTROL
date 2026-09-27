import fs from 'fs'

const s2sRouteCode = `import { NextRequest, NextResponse } from 'next/server';
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
            return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
        }

        if (!verifiedPayload.exp || !verifiedPayload.iat) {
            return NextResponse.json({ error: "Invalid Token Claims" }, { status: 401 });
        }

        if (verifiedPayload.action !== "read_master_data") {
            return NextResponse.json({ error: "Forbidden" }, { status: 403 });
        }

        const { searchParams } = new URL(req.url);
        let limit = parseInt(searchParams.get('limit') || '1000');
        let offset = parseInt(searchParams.get('offset') || '0');
        const id = searchParams.get('id');
        const idsParam = searchParams.get('ids');
        const search = searchParams.get('search');
        const status = searchParams.get('status');

        if (isNaN(limit) || limit < 1 || limit > 5000) limit = 1000;
        if (isNaN(offset) || offset < 0) offset = 0;

        const admin = createAdminClient();
        
        const buildQuery = (selectCols: string) => {
            let q = admin.from('measurement_units').select(selectCols, { count: 'exact' });

            if (id) {
                q = q.eq('id', id);
            }
            if (idsParam) {
                const idsArray = idsParam.split(',').map(i => i.trim()).filter(Boolean);
                if (idsArray.length > 0) {
                    q = q.in('id', idsArray);
                }
            }
            if (search) {
                if (selectCols.includes('business_name')) {
                    q = q.or(\`name.ilike.%\${search}%,canonical_code.ilike.%\${search}%,standard_code.ilike.%\${search}%,symbol.ilike.%\${search}%,business_name.ilike.%\${search}%,short_name.ilike.%\${search}%\`);
                } else {
                    q = q.or(\`name.ilike.%\${search}%,canonical_code.ilike.%\${search}%,standard_code.ilike.%\${search}%,symbol.ilike.%\${search}%\`);
                }
            }
            if (status && status !== 'ALL') {
                q = q.eq('status', status);
            }

            return q.order('name', { ascending: true }).range(offset, offset + limit - 1);
        }

        let { data, count, error } = await buildQuery('id, canonical_code, standard_code, name, symbol, category, aliases, status, source, source_version, business_name, short_name, is_business');

        if (error && (error.code === '42703' || error.message?.includes('Could not find') || error.code === 'PGRST204' || error.code === 'PGRST200')) {
            // Fallback for unapplied migration
            const fallback = await buildQuery('id, canonical_code, standard_code, name, symbol, category, aliases, status, source, source_version');
            data = fallback.data;
            count = fallback.count;
            error = fallback.error;
        }

        if (error) {
            console.error('[S2S API] /master-data/units DB Error:', error);
            return NextResponse.json({ error: 'Service unavailable' }, { status: 503 });
        }

        return NextResponse.json({ data, count, limit, offset, provider: 'global-control' });
    } catch (err: any) {
        console.error('[S2S API] /master-data/units Error:', err);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
`

fs.writeFileSync('src/app/api/s2s/master-data/units/route.ts', s2sRouteCode)
