import * as dotenv from 'dotenv';
dotenv.config({ path: '.env.local' });

async function run() {
    const url = `${process.env.NEXT_PUBLIC_SUPABASE_URL}/rest/v1/gst_rate_master`;
    const res = await fetch(url, { 
        method: 'POST',
        headers: { 
            apikey: process.env.SUPABASE_SERVICE_ROLE_KEY!, 
            Authorization: `Bearer ${process.env.SUPABASE_SERVICE_ROLE_KEY!}`,
            'Content-Type': 'application/json',
            'Prefer': 'return=representation'
        },
        body: JSON.stringify({
            hsn_sac_code: "9999",
            description: "Test Check Constraint",
            cgst_rate: 9,
            sgst_rate: 9,
            igst_rate: 18,
            cess_rate: 0,
            is_exempt: false,
            effective_from: "2024-01-01"
        })
    } as unknown as RequestInit);
    console.log(JSON.stringify(await res.json(), null, 2));
}
run();
