import { GET } from './src/app/api/s2s/master-data/countries/route';
import { SignJWT } from 'jose';

async function run() {
  let passed = 0, failed = 0;
  const test = async (name: string, fn: Function) => {
    try { await fn(); console.log('[PASS] ' + name); passed++; }
    catch (e: any) { console.log('[FAIL] ' + name + ' — ' + e.message); failed++; }
  };
  const secretKey = new TextEncoder().encode(process.env.GLOBAL_CONTROL_HMAC_SECRET);
  const makeReq = (token: any) => (({ headers: { get: () => 'Bearer ' + token } } as unknown as Request));

  await test('Mapping RPC failure ? 500, no default-currency success fallback', async () => {
    const token = await new SignJWT({ action: 'read_master_data' })
      .setProtectedHeader({ alg: 'HS256' })
      .setIssuer('NAMISH_ERP').setAudience('NAMISH_GLOBAL_CONTROL')
      .setIssuedAt().setExpirationTime('1m')
      .sign(secretKey);
    const res = await GET(makeReq(token));
    const data = await res.json();
    if (res.status !== 500 || data.error !== 'Internal Server Error')
      throw new Error('Expected 500 Internal Server Error, got ' + res.status + ' ' + JSON.stringify(data));
    if (Array.isArray(data)) throw new Error('Must not return data array on mapping failure');
  });

  console.log('\nTests: ' + passed + ' passed, ' + failed + ' failed');
  process.exit(failed > 0 ? 1 : 0);
}
run();
