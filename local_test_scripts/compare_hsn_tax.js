const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
require('dotenv').config({ path: '.env.local' });

const supabase = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);

async function run() {
    // 1. Get the last published release
    const { data: pubData, error: pubErr } = await supabase
        .from('catalog_releases')
        .select('id')
        .eq('status', 'PUBLISHED')
        .order('created_at', { ascending: false })
        .limit(1)
        .single();
    
    if (pubErr) {
        console.error("No published release:", pubErr);
        return;
    }
    const pubId = pubData.id;
    const draftId = 'ca7c5ea6-2f52-44de-bd42-f46b253a4d63';

    console.log(`Comparing Published (${pubId}) with Draft (${draftId})`);

    // We compare HSN and TAX items
    const { data: pubItems } = await supabase
        .from('catalog_release_items')
        .select('item_type, item_id, payload')
        .eq('release_id', pubId)
        .in('item_type', ['HSN_SAC', 'TAX_PROFILE']);

    const { data: draftItems } = await supabase
        .from('catalog_release_items')
        .select('item_type, item_id, payload')
        .eq('release_id', draftId)
        .in('item_type', ['HSN_SAC', 'TAX_PROFILE']);

    const pubMap = new Map(pubItems.map(i => [`${i.item_type}-${i.item_id}`, i.payload]));
    const draftMap = new Map(draftItems.map(i => [`${i.item_type}-${i.item_id}`, i.payload]));

    let differences = 0;
    let missingInDraft = 0;
    let extraInDraft = 0;

    for (const [key, pubPayload] of pubMap.entries()) {
        if (!draftMap.has(key)) {
            missingInDraft++;
        } else {
            const draftPayload = draftMap.get(key);
            if (JSON.stringify(pubPayload) !== JSON.stringify(draftPayload)) {
                differences++;
            }
        }
    }

    for (const key of draftMap.keys()) {
        if (!pubMap.has(key)) {
            extraInDraft++;
        }
    }

    console.log(`Missing in Draft: ${missingInDraft}`);
    console.log(`Extra in Draft: ${extraInDraft}`);
    console.log(`Payload Differences: ${differences}`);
    if (differences === 0 && missingInDraft === 0 && extraInDraft === 0) {
        console.log("SUCCESS: HSN/TAX are exactly equal by ID and payload!");
    } else {
        console.log("MISMATCH!");
    }
}

run();
