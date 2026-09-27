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
    // 1. Get all distinct categories and their counts
    const { data: cats } = await admin
        .from('measurement_units')
        .select('category')
        .order('category');

    const tally: Record<string, number> = {};
    for (const row of cats ?? []) {
        tally[row.category] = (tally[row.category] ?? 0) + 1;
    }
    console.log('=== DISTINCT CATEGORIES ===');
    for (const [cat, n] of Object.entries(tally).sort((a, b) => b[1] - a[1])) {
        console.log(`  "${cat}": ${n}`);
    }

    // 2. Count for category "1"
    const { count: cat1Count } = await admin
        .from('measurement_units')
        .select('*', { count: 'exact', head: true })
        .eq('category', '1');
    console.log(`\nCategory "1" count: ${cat1Count}`);

    // 3. Check the A1 record encoding
    const { data: a1 } = await admin
        .from('measurement_units')
        .select('canonical_code, name, symbol, category, status, description')
        .eq('canonical_code', 'UNECE_REC20_A1')
        .single();
    console.log('\n=== A1 RECORD ===');
    console.log(JSON.stringify(a1, null, 2));
    if (a1?.name) {
        console.log('name hex:', Buffer.from(a1.name, 'utf8').toString('hex'));
    }
})();
