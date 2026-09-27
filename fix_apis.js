import fs from 'fs'

function fixDataHub() {
    let code = fs.readFileSync('src/app/api/data-hub/units/route.ts', 'utf8')
    
    // We want to replace the query part with a fallback.
    const newCode = `import { NextRequest, NextResponse } from 'next/server'
import { createAdminClient } from '@/utils/supabase/admin'
import { getAuthContext } from '@/utils/auth'

export async function GET(req: NextRequest) {
    try {
        const { staff } = await getAuthContext()
        if (!staff) return NextResponse.json({ error: 'Unauthorized Access: Staff permissions required' }, { status: 403 })

        const { searchParams } = new URL(req.url)
        const limit = parseInt(searchParams.get('limit') || '100')
        const offset = parseInt(searchParams.get('offset') || '0')
        const search = searchParams.get('search')
        const category = searchParams.get('category')
        const status = searchParams.get('status')
        const isCommon = searchParams.get('is_common')

        const admin = createAdminClient()
        
        const buildQuery = (selectCols) => {
            let q = admin.from('measurement_units').select(selectCols, { count: 'exact' })
            if (search) {
                if (selectCols.includes('business_name')) {
                    q = q.or('name.ilike.%' + search + '%,canonical_code.ilike.%' + search + '%,standard_code.ilike.%' + search + '%,symbol.ilike.%' + search + '%,business_name.ilike.%' + search + '%,short_name.ilike.%' + search + '%')
                } else {
                    q = q.or('name.ilike.%' + search + '%,canonical_code.ilike.%' + search + '%,standard_code.ilike.%' + search + '%,symbol.ilike.%' + search + '%')
                }
            }
            if (category && category !== 'ALL') q = q.eq('category', category)
            if (status && status !== 'ALL') q = q.eq('status', status)
            if (isCommon === 'true' && selectCols.includes('is_common')) q = q.eq('is_common', true)
            
            return q.order('name', { ascending: true }).range(offset, offset + limit - 1)
        }

        let { data, count, error } = await buildQuery('id, canonical_code, standard_code, name, symbol, category, aliases, status, source, source_version, business_name, short_name, is_common')
        
        if (error && error.code === 'PGRST200' || error?.message?.includes('Could not find') || error?.code === 'PGRST204' || error?.code === '42703') {
            // Fallback for unapplied migration
            const fallback = await buildQuery('id, canonical_code, standard_code, name, symbol, category, aliases, status, source, source_version')
            data = fallback.data
            count = fallback.count
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

export async function PATCH(req: NextRequest) {
    try {
        const { staff } = await getAuthContext()
        if (!staff) return NextResponse.json({ error: 'Unauthorized Access: Staff permissions required' }, { status: 403 })

        const body = await req.json()
        const { id, is_common } = body

        if (!id) return NextResponse.json({ error: 'Missing unit ID' }, { status: 400 })

        const admin = createAdminClient()
        const { data, error } = await admin
            .from('measurement_units')
            .update({ is_common })
            .eq('id', id)
            .select()
            .single()

        if (error) {
            console.error('[API] /data-hub/units PATCH Error:', error)
            return NextResponse.json({ error: 'Failed to update unit metadata.' }, { status: 500 })
        }

        return NextResponse.json(data)
    } catch (err: any) {
        console.error('[API] /data-hub/units PATCH Unexpected Error:', err)
        return NextResponse.json({ error: 'An unexpected error occurred.' }, { status: 500 })
    }
}
`
    fs.writeFileSync('src/app/api/data-hub/units/route.ts', newCode)
}

function fixS2S() {
    const newCode = `import { NextRequest, NextResponse } from 'next/server';
import { createAdminClient } from '@/utils/supabase/admin';
import { authenticateMachineRequest } from '@/utils/auth';

export async function GET(req: NextRequest) {
    try {
        const authResult = await authenticateMachineRequest(req);
        if (!authResult.valid) {
            return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
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
        
        const buildQuery = (selectCols) => {
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

        let { data, count, error } = await buildQuery('id, canonical_code, standard_code, name, symbol, category, aliases, status, source, source_version, business_name, short_name, is_common');

        if (error && (error.code === '42703' || error.message?.includes('Could not find'))) {
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
    fs.writeFileSync('src/app/api/s2s/master-data/units/route.ts', newCode)
}

fixDataHub()
fixS2S()
