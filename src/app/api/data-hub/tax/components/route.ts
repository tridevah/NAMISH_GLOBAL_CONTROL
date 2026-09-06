import { NextRequest, NextResponse } from "next/server";
import { createAdminClient } from "@/utils/supabase/admin";
import { getAuthContext } from "@/utils/auth";

export async function GET(req: NextRequest) {
    try {
        const { user, staff } = await getAuthContext();
        if (!user || !staff) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

        const supabase = createAdminClient();
        const { searchParams } = new URL(req.url);
        
        let query = supabase.from('tax_components').select('*');
        if (searchParams.has('status')) query = query.eq('status', searchParams.get('status'));
        
        const { data, error } = await query;
        if (error) throw error;
        return NextResponse.json(data);
    } catch (error: any) {
        return NextResponse.json({ error: error.message }, { status: 500 });
    }
}

export async function POST(req: NextRequest) {
    try {
        const { user, staff } = await getAuthContext();
        if (!user || !staff) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
        if (staff.role === 'AUDITOR') return NextResponse.json({ error: 'Forbidden' }, { status: 403 });

        const payload = await req.json();
        const supabase = createAdminClient();
        const { data, error } = await supabase.rpc('rpc_mutate_tax_entity', {
            p_table_name: 'tax_components',
            p_action: 'INSERT',
            p_payload: payload,
            p_actor_id: user.id
        });
        if (error) throw error;
        return NextResponse.json(data);
    } catch (error: any) {
        return NextResponse.json({ error: error.message }, { status: 500 });
    }
}

export async function PATCH(req: NextRequest) {
    try {
        const { user, staff } = await getAuthContext();
        if (!user || !staff) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
        if (staff.role === 'AUDITOR') return NextResponse.json({ error: 'Forbidden' }, { status: 403 });

        const payload = await req.json();
        const supabase = createAdminClient();
        const { id, ...rest } = payload;
        const { data, error } = await supabase.rpc('rpc_mutate_tax_entity', {
            p_table_name: 'tax_components',
            p_action: 'UPDATE',
            p_payload: payload,
            p_actor_id: user.id
        });
        if (error) throw error;
        return NextResponse.json(data);
    } catch (error: any) {
        return NextResponse.json({ error: error.message }, { status: 500 });
    }
}
