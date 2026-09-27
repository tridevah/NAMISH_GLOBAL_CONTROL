import { jwtVerify } from 'jose';

async function check() {
    const secret = process.env.GLOBAL_CONTROL_HMAC_SECRET;
    console.log('Secret in GC env:', secret);
    
    // Create token exactly like verify.mjs
    const { SignJWT } = await import('jose');
    const token = await new SignJWT({ action: 'read_master_data' })
        .setProtectedHeader({ alg: 'HS256' })
        .setIssuedAt()
        .setIssuer('NAMISH_ERP')
        .setAudience('NAMISH_GLOBAL_CONTROL')
        .setExpirationTime('1m')
        .sign(new TextEncoder().encode(secret));
        
    try {
        await jwtVerify(token, new TextEncoder().encode(secret), {
            algorithms: ["HS256"],
            issuer: "NAMISH_ERP",
            audience: "NAMISH_GLOBAL_CONTROL",
            maxTokenAge: "1m",
        });
        console.log('jwtVerify succeeded in GC');
    } catch(e) {
        console.log('jwtVerify failed:', e);
    }
}
check();
