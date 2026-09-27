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

    const url = 'http://localhost:3001/api/s2s/master-data/taxes?limit=500';
    const res = await fetch(url, {
        headers: { 'Authorization': `Bearer ${token}` }
    });
    console.log("HTTP Status:", res.status);
    const text = await res.text();
    if (res.ok) {
        const data = JSON.parse(text);
        const standard = data.rows?.find((r: any) => r.rate_name.includes('Standard Rate 18%') || r.category === 'STANDARD');
        const conditional = data.rows?.find((r: any) => r.category === 'SPECIAL' || r.conditions !== null);
        console.log("Returned Total (overall):", data.total);
        console.log("--- Standard Record ---");
        console.log(JSON.stringify(standard, null, 2));
        console.log("--- Conditional Record ---");
        console.log(JSON.stringify(conditional, null, 2));
    } else {
        console.log("Failed Body:", text.substring(0, 500));
    }
}
run();
