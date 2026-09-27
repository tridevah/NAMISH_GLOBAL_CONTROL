import { createAdminClient } from './src/utils/supabase/admin'

async function run() {
    console.log("=== CHECK 1: Confirm 30 agreed units (DB Level) ===");
    const admin = createAdminClient();
    const { data: units, error: err1 } = await admin
        .from('measurement_units')
        .select('*')
        .eq('is_business', true)
        .eq('status', 'ACTIVE');
    
    if (err1) {
        console.log("FAIL Check 1 DB:", err1);
    } else {
        console.log(`Found ${units.length} ACTIVE business units.`);
        if (units.length >= 30) {
            console.log("PASS: 30+ business units found with names, short names and ACTIVE status.");
        } else {
            console.log("FAIL: Less than 30 business units.");
        }
    }

    console.log("\n=== CHECK 2: Verify KGS, kgs and Kg (DB Level) ===");
    const terms = ['KGS', 'kgs', 'Kg'];
    for (const term of terms) {
        const { data, error } = await admin
            .from('measurement_units')
            .select('*')
            .eq('is_business', true)
            .or(`aliases_text.ilike.%${term}%`);
        
        if (error) {
            console.log(`FAIL Search "${term}":`, error);
        } else {
            const found = data.some((u: any) => u.canonical_code === 'UNECE_REC20_KGM');
            console.log(`Search "${term}" -> found KILOGRAMS? ${found ? 'PASS' : 'FAIL'}`);
        }
    }

    console.log("\n=== CHECK 3: Duplicate POST BAGS/Bag (DB Level RPC) ===");
    const { data: rpcData, error: rpcErr } = await admin.rpc('rpc_add_business_unit', {
        p_business_name: 'BAGS',
        p_short_name: 'Bag',
        p_aliases: []
    });

    if (rpcErr) {
        console.log(`RPC Error Code: ${rpcErr.code}`);
        console.log(`RPC Error Msg: ${rpcErr.message}`);
        if (rpcErr.code === '23505') {
            console.log("PASS: RPC raised 23505 unique_violation as expected.");
        } else {
            console.log("FAIL: RPC raised unexpected error.");
        }
    } else {
        console.log("FAIL: RPC did not raise error on duplicate.");
    }
}
run();
