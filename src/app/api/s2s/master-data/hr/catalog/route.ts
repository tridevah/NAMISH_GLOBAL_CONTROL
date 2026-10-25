import { NextRequest, NextResponse } from 'next/server';
import { jwtVerify } from 'jose';
import { createAdminClient } from '@/utils/supabase/admin';
import { fetchAllPages } from '@/utils/hrCatalogExport';
import titleOverrides from '@/data/hr_title_overrides.json';

export async function GET(req: NextRequest) {
    try {
        const authHeader = req.headers.get('Authorization');
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return NextResponse.json({ error: 'Unauthorized', details: 'No Auth Header' }, { status: 401 });
        }

        const token = authHeader.substring(7);
        const secretStr = process.env.GLOBAL_CONTROL_HMAC_SECRET || process.env.HMAC_SECRET;
        if (!secretStr) {
            return NextResponse.json({ error: 'Service Unavailable' }, { status: 503 });
        }

        const secretKey = new TextEncoder().encode(secretStr);
        let verifiedPayload: Record<string, unknown>;
        try {
            const { payload } = await jwtVerify(token, secretKey, {
                algorithms: ['HS256'],
                issuer: 'NAMISH_ERP',
                audience: 'NAMISH_GLOBAL_CONTROL',
                maxTokenAge: '1m',
            });
            verifiedPayload = payload as Record<string, unknown>;
        } catch (e: any) {
            return NextResponse.json({ error: 'Unauthorized', details: e.message || String(e) }, { status: 401 });
        }

        if (verifiedPayload.action !== 'read_master_data') {
            return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
        }

        const admin = createAdminClient();

        // Sequential on purpose: one consistent failure path, no partial success.
        const departments = await fetchAllPages(admin, 'departments', 'id, code, name, title_display_name, status', ['id']);
        const designations = await fetchAllPages(admin, 'designations', 'id, code, name, title_mode, title_template, status', ['id']);
        const mappings = await fetchAllPages(admin, 'department_designations', 'department_id, designation_id, status', ['department_id', 'designation_id']);
        const sub_departments = await fetchAllPages(admin, 'sub_departments', 'id, department_id, code, name, title_display_name, description, status', ['id']);
        const sub_department_mappings = await fetchAllPages(admin, 'sub_department_designations', 'sub_department_id, designation_id, status', ['sub_department_id', 'designation_id']);

        return NextResponse.json({
            success: true,
            data: { 
                departments, 
                designations, 
                mappings, 
                sub_departments, 
                sub_department_mappings,
                title_overrides: titleOverrides 
            }
        });
    } catch (e: any) {
        console.error('[GC HR Catalog API] Error:', e);
        return NextResponse.json({ error: e.message || 'Internal Server Error' }, { status: 500 });
    }
}