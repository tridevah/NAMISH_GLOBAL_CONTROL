import { GET } from './src/app/api/s2s/master-data/countries/route';
import { SignJWT } from 'jose';

async function run() {
    let passed = 0, failed = 0;
    const test = async (name: string, fn: Function) => {
        try {
            await fn();
            console.log('[PASS] ' + name);
            passed++;
        } catch (e: any) {
            console.log('[FAIL] ' + name + ' - ' + e.message);
            failed++;
        }
    };

    const secretKey = new TextEncoder().encode(process.env.GLOBAL_CONTROL_HMAC_SECRET!)
    const makeReq = (token: any) => (({
        headers: { get: () => 'Bearer ' + token }
    } as unknown as Request));

    await test('Valid machine token returns authoritative country/currency mappings from RPC', async () => {
        const token = await new SignJWT({ action: 'read_master_data' })
            .setProtectedHeader({ alg: 'HS256' })
            .setIssuer('NAMISH_ERP')
            .setAudience('NAMISH_GLOBAL_CONTROL')
            .setIssuedAt()
            .setExpirationTime('1m')
            .sign(secretKey);
        
        const res = await GET(makeReq(token));
        const data = await res.json();
        if (res.status !== 200) throw new Error('Expected 200, got ' + res.status);
        if (!data[0] || !data[0].supported_currencies || data[0].supported_currencies[0] !== 'INR') {
            throw new Error('Missing or incorrect currencies in response');
        }
    });

    console.log("\nTests: " + passed + " passed, " + failed + " failed");
    process.exit(failed > 0 ? 1 : 0);
}
run();
