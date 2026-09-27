import * as dotenv from 'dotenv';
dotenv.config({ path: '.env.local' });
import { SignJWT } from "jose";

async function run() {
    const secretStr = process.env.GLOBAL_CONTROL_HMAC_SECRET;
    const secretKey = new TextEncoder().encode(secretStr);
    
    // Create token
    const token = await new SignJWT({ action: 'read_master_data' })
        .setProtectedHeader({ alg: 'HS256' })
        .setIssuedAt()
        .setExpirationTime('1m')
        .setIssuer('NAMISH_ERP')
        .setAudience('NAMISH_GLOBAL_CONTROL')
        .sign(secretKey);

    // Fetch the real-estate context-only record with statutory 7.5 and effective 5.
    const url = 'http://localhost:3001/api/s2s/master-data/taxes?active_only=false';
    const res = await fetch(url, {
        headers: { 'Authorization': `Bearer ${token}` }
    });
    
    console.log("HTTP Status:", res.status);
    const text = await res.text();
    if (res.ok) {
        const data = JSON.parse(text);
        const realEstate = data.rows?.find((r: any) => 
            r.statutory_rate_percent === 7.5 && 
            r.effective_display_percent === 5 && 
            r.erp_visibility === 'CONTEXT_ONLY'
        );
        console.log("Returned Total (overall):", data.total);
        console.log("--- Real Estate Conditional Record ---");
        console.log(JSON.stringify(realEstate, null, 2));
    } else {
        console.log("Failed Body:", text.substring(0, 500));
    }
}
run();
