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

    const targetUrl = 'http://localhost:3001/api/s2s/master-data/taxes?id=e6dd64cd-78e9-4e3c-a300-e09d25c54c99&country=cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d&active_only=true';
    console.log("Target URL:", targetUrl);
    
    const res = await fetch(targetUrl, {
        headers: { 'Authorization': `Bearer ${token}` }
    });
    
    console.log("HTTP Status:", res.status);
    const text = await res.text();
    if (res.ok) {
        console.log("Response Body:");
        console.log(JSON.stringify(JSON.parse(text), null, 2));
    } else {
        console.log("Failed Body:", text.substring(0, 500));
    }
}
run();
