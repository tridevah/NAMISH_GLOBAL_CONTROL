import * as dotenv from 'dotenv';
dotenv.config({ path: '.env.local' });

async function run() {
    const url = `${process.env.NEXT_PUBLIC_SUPABASE_URL}/rest/v1/gst_rate_master?select=*&is_exempt=eq.true`;
    const res = await fetch(url, { 
        headers: { 
            apikey: process.env.SUPABASE_SERVICE_ROLE_KEY!, 
            Authorization: `Bearer ${process.env.SUPABASE_SERVICE_ROLE_KEY!}` 
        } 
    } as unknown as RequestInit);
    console.log(JSON.stringify(await res.json(), null, 2));
}
run();
