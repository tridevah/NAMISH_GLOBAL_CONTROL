import { config } from 'dotenv';
import * as path from 'path';
config({ path: path.resolve(__dirname, '../.env.local') });
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY!;
const admin = createClient(supabaseUrl, supabaseKey, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false }
});

(async () => {
    // Verify real HTTP API via supabaseAdmin directly (simulates what the route handler does)
    console.log('=== REAL API SIMULATION (service_role, no mock) ===');

    const tests: Array<{ label: string; params: Record<string, string | number> }> = [
        { label: 'Default (limit=5)',           params: { limit: 5, offset: 0 } },
        { label: 'Search KGM',                  params: { limit: 100, offset: 0, search: 'KGM' } },
        { label: 'Search MTR',                  params: { limit: 100, offset: 0, search: 'MTR' } },
        { label: 'Search LTR',                  params: { limit: 100, offset: 0, search: 'LTR' } },
        { label: 'Category "1" (177 expected)', params: { limit: 5, offset: 0, category: '1' } },
        { label: 'Status INACTIVE',             params: { limit: 5, offset: 0, status: 'INACTIVE' } },
        { label: 'Status ACTIVE + Category 1M', params: { limit: 5, offset: 0, status: 'ACTIVE', category: '1M' } },
        { label: 'Pagination page 2 (offset=5)',params: { limit: 5, offset: 5 } },
    ];

    for (const test of tests) {
        let query = admin.from('measurement_units').select(
            'id, canonical_code, standard_code, name, symbol, category, aliases, status, source, source_version',
            { count: 'exact' }
        );
        const p = test.params;
        if (p.search) query = (query as any).or(`name.ilike.%${p.search}%,canonical_code.ilike.%${p.search}%,standard_code.ilike.%${p.search}%,symbol.ilike.%${p.search}%`);
        if (p.category && p.category !== 'ALL') query = (query as any).eq('category', p.category);
        if (p.status && p.status !== 'ALL') query = (query as any).eq('status', p.status);
        query = (query as any).order('name', { ascending: true }).range(Number(p.offset), Number(p.offset) + Number(p.limit) - 1);

        const { data, count, error } = await (query as any);
        if (error) {
            console.log(`\n[${test.label}] ERROR: ${error.message}`);
        } else {
            console.log(`\n[${test.label}] count=${count}, rows=${data?.length}`);
            if (data?.length) {
                const first = data[0];
                console.log(`  first: name="${first.name}" | code=${first.standard_code} | cat=${first.category} | status=${first.status}`);
            }
        }
    }

    // Also check A1 encoding specifically
    const { data: a1 } = await admin.from('measurement_units').select('name, symbol').eq('canonical_code', 'UNECE_REC20_A1').single();
    console.log(`\n=== A1 ENCODING ===`);
    console.log(`name: ${a1?.name}`);
    console.log(`name codepoints:`, [...(a1?.name ?? '')].map(c => `U+${c.codePointAt(0)!.toString(16).toUpperCase().padStart(4, '0')}`).join(' '));
    console.log(`symbol: ${a1?.symbol}`);
})();
