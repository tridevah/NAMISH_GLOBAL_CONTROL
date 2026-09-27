import { GET } from './src/app/api/s2s/master-data/countries/route';
import { SignJWT } from 'jose';

// Controlled fixture: exact shape rpc_get_country_currencies returns after correction.
// One row per country; joined on default_currency_code where cu.status = 'ACTIVE'.
const RPC_CURRENCY_ROWS = [
  { iso_alpha_code: 'INR', iso_numeric_code: '356', name: 'Indian Rupee',
    default_symbol: '?', native_symbol: '?', minor_units: 2,
    status: 'ACTIVE', country_iso2: 'IN', country_iso3: 'IND', country_name: 'India' },
  { iso_alpha_code: 'USD', iso_numeric_code: '840', name: 'US Dollar',
    default_symbol: '\$', native_symbol: '\$', minor_units: 2,
    status: 'ACTIVE', country_iso2: 'US', country_iso3: 'USA', country_name: 'United States' }
];

const RPC_COUNTRIES = [
  { id: 'uuid-in', iso2: 'IN', iso3: 'IND', display_name: 'India' },
  { id: 'uuid-us', iso2: 'US', iso3: 'USA', display_name: 'United States' }
];

// createAdminClient is injected via module fixture (file-swap)
// The mock in src/utils/supabase/admin.ts is already active when this runs.

async function run() {
  let passed = 0, failed = 0;
  const test = async (name: string, fn: Function) => {
    try { await fn(); console.log('[PASS] ' + name); passed++; }
    catch (e: any) { console.log('[FAIL] ' + name + ' — ' + e.message); failed++; }
  };

  const secretKey = new TextEncoder().encode(process.env.GLOBAL_CONTROL_HMAC_SECRET);
  const makeReq = (token: any) => (({ headers: { get: () => 'Bearer ' + token } } as unknown as Request));

  // -- Test 1: Valid token returns correct country/currency mapping ----------
  await test('Valid token ? authoritative country+currency mapping per RPC contract', async () => {
    const token = await new SignJWT({ action: 'read_master_data' })
      .setProtectedHeader({ alg: 'HS256' })
      .setIssuer('NAMISH_ERP').setAudience('NAMISH_GLOBAL_CONTROL')
      .setIssuedAt().setExpirationTime('1m')
      .sign(secretKey);

    const res = await GET(makeReq(token));
    const data = await res.json();
    if (res.status !== 200) throw new Error('Expected 200, got ' + res.status + ': ' + JSON.stringify(data));
    const india = data.find((c: any) => c.iso2 === 'IN');
    const us    = data.find((c: any) => c.iso2 === 'US');
    if (!india) throw new Error('India missing from result');
    if (india.supported_currencies[0] !== 'INR') throw new Error('India currency should be INR, got: ' + JSON.stringify(india.supported_currencies));
    if (!us || us.supported_currencies[0] !== 'USD') throw new Error('US currency should be USD, got: ' + JSON.stringify(us?.supported_currencies));
  });

  // -- Test 2: Missing exp ? 401 --------------------------------------------
  await test('Missing exp claim ? 401 Invalid Token Claims', async () => {
    const token = await new SignJWT({ action: 'read_master_data' })
      .setProtectedHeader({ alg: 'HS256' })
      .setIssuer('NAMISH_ERP').setAudience('NAMISH_GLOBAL_CONTROL')
      .setIssuedAt()
      .sign(secretKey);

    const res = await GET(makeReq(token));
    const data = await res.json();
    if (res.status !== 401 || data.error !== 'Invalid Token Claims')
      throw new Error('Expected 401 Invalid Token Claims, got ' + res.status + ' ' + JSON.stringify(data));
  });

  // -- Test 3: Wrong action ? 403 -------------------------------------------
  await test('Wrong action claim ? 403 Forbidden', async () => {
    const token = await new SignJWT({ action: 'write_data' })
      .setProtectedHeader({ alg: 'HS256' })
      .setIssuer('NAMISH_ERP').setAudience('NAMISH_GLOBAL_CONTROL')
      .setIssuedAt().setExpirationTime('1m')
      .sign(secretKey);

    const res = await GET(makeReq(token));
    const data = await res.json();
    if (res.status !== 403 || data.error !== 'Forbidden')
      throw new Error('Expected 403 Forbidden');
  });

  // -- Test 4: Expired token ? 401 ------------------------------------------
  await test('Expired token ? 401 Unauthorized', async () => {
    const iat = Math.floor(Date.now() / 1000) - 120;
    const exp = iat + 1;
    const token = await new SignJWT({ action: 'read_master_data' })
      .setProtectedHeader({ alg: 'HS256' })
      .setIssuer('NAMISH_ERP').setAudience('NAMISH_GLOBAL_CONTROL')
      .setIssuedAt(iat).setExpirationTime(exp)
      .sign(secretKey);

    const res = await GET(makeReq(token));
    if (res.status !== 401) throw new Error('Expected 401, got ' + res.status);
  });

  console.log('\nTests: ' + passed + ' passed, ' + failed + ' failed');
  process.exit(failed > 0 ? 1 : 0);
}
run();
