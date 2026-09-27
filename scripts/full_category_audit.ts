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
    // Reproduce the bug: fetch only first 1000 rows ordered by category (what the old script did)
    console.log('=== REPRODUCTION: Fetching only first 1000 rows ordered by category ===');
    const { data: bugged, count: buggedCount } = await admin
        .from('measurement_units')
        .select('category', { count: 'exact' })
        .order('category')
        .limit(1000);
    
    const buggedTally: Record<string, number> = {};
    for (const row of bugged ?? []) {
        buggedTally[row.category] = (buggedTally[row.category] ?? 0) + 1;
    }
    console.log(`Rows fetched: ${bugged?.length}, DB total: ${buggedCount}`);
    console.log('Partial distribution:', buggedTally);

    // Correct approach: paginate through ALL rows
    console.log('\n=== CORRECT: Paginating through all 2136 rows ===');
    const PAGE_SIZE = 1000;
    let offset = 0;
    const fullTally: Record<string, number> = {};
    let totalFetched = 0;

    while (true) {
        const { data, error } = await admin
            .from('measurement_units')
            .select('category')
            .order('id')              // deterministic ordering by stable PK, not category
            .range(offset, offset + PAGE_SIZE - 1);

        if (error) { console.error('Error:', error); break; }
        if (!data || data.length === 0) break;

        for (const row of data) {
            fullTally[row.category] = (fullTally[row.category] ?? 0) + 1;
        }
        totalFetched += data.length;
        offset += data.length;
        if (data.length < PAGE_SIZE) break;
    }

    console.log(`Total rows fetched: ${totalFetched}`);
    const sortedEntries = Object.entries(fullTally).sort((a, b) => b[1] - a[1]);
    console.log(`Distinct categories: ${sortedEntries.length}`);
    
    let sum = 0;
    for (const [cat, n] of sortedEntries) {
        console.log(`  "${cat}": ${n}`);
        sum += n;
    }
    console.log(`Sum of all category counts: ${sum}`);
    console.log(`Category "1": ${fullTally['1']}`);
    console.log(`Category "2": ${fullTally['2']}`);

    // Output the full sorted list for UI use
    const forUI = sortedEntries.map(([cat]) => cat).sort();
    console.log('\nFull sorted category list for UI:');
    console.log(JSON.stringify(forUI, null, 2));
})();
