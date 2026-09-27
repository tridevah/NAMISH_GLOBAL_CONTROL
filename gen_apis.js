const fs = require('fs');
const path = require('path');

const routes = ['regimes', 'components', 'codes', 'rates', 'hsn-sac', 'assignments'];
const tableMap = {
    'regimes': 'tax_regimes',
    'components': 'tax_components',
    'codes': 'tax_codes',
    'rates': 'tax_rates',
    'hsn-sac': 'hsn_sac',
    'assignments': 'hsn_sac_tax_codes'
};

routes.forEach(r => {
    const table = tableMap[r];
    const content = import { NextRequest, NextResponse } from "next/server";
import { createAdminClient } from "@/utils/supabase/admin";

export async function GET(req: NextRequest) {
    try {
        const supabase = createAdminClient();
        const { searchParams } = new URL(req.url);
        
        let query = supabase.from('').select('*');
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
        const payload = await req.json();
        const supabase = createAdminClient();
        const { data, error } = await supabase.rpc('rpc_mutate_tax_entity', {
            p_table_name: '',
            p_action: 'INSERT',
            p_payload: payload,
            p_actor_id: '00000000-0000-0000-0000-000000000000' // Mock actor id for now
        });
        if (error) throw error;
        return NextResponse.json(data);
    } catch (error: any) {
        return NextResponse.json({ error: error.message }, { status: 500 });
    }
}

export async function PATCH(req: NextRequest) {
    try {
        const payload = await req.json();
        const supabase = createAdminClient();
        const { data, error } = await supabase.rpc('rpc_mutate_tax_entity', {
            p_table_name: '',
            p_action: 'UPDATE',
            p_payload: payload,
            p_actor_id: '00000000-0000-0000-0000-000000000000'
        });
        if (error) throw error;
        return NextResponse.json(data);
    } catch (error: any) {
        return NextResponse.json({ error: error.message }, { status: 500 });
    }
}
;
    fs.writeFileSync(path.join('src/app/api/data-hub/tax', r, 'route.ts'), content);
});
