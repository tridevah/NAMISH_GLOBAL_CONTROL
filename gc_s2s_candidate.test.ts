import { GET } from './src/app/api/s2s/master-data/countries/route';
import { SignJWT } from 'jose';

// Controlled fixture: exact shape rpc_get_country_currencies returns
// after the correction is applied.  One row per country.
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

async function run() {
  let passed = 0, failed = 0;
  const test = async (name: string, fn: Function) => {
    try { await fn(); console.log('[PASS] ' + name); passed++; }
    catch (e: any) { console.log('[FAIL] ' + name + ' — ' + e.message); failed++; }
  };

  const secretKey = new TextEncoder().encode(process.env.GLOBAL_CONTROL_HMAC_SECRET);
  const makeReq = (token: any) => (({ headers: { get: () => 'Bearer ' + token } } as unknown as Request));

  const makeAdminMock = (opts = {}) => ({
    rpc: async (name: string) => {
      if ('countryError' in opts && name === 'rpc_get_countries') return { data: null, error: opts.countryError };
      if ('currencyError' in opts && name === 'rpc_get_country_currencies') return { data: null, error: opts.currencyError };
      if (name === 'rpc_get_countries') return { data: RPC_COUNTRIES };
      if (name === 'rpc_get_country_currencies') return { data: RPC_CURRENCY_ROWS };
    }
  });

  const originalAdmin = await import('./src/utils/supabase/admin');
  const originalFn = originalAdmin.createAdminClient;

  // Helper to temporarily replace createAdminClient
  const withMock = async (mock: any, fn: Function) => {
    (originalAdmin as any).createAdminClient = () => mock;
    try { await fn(); } finally { (originalAdmin as any).createAdminClient = originalFn; }
  };

  // -- Test 1: Valid token returns correct country/currency mapping ----------
  await test('Valid token ? authoritative country+currency mapping per RPC contract', async () => {
    const token = await new SignJWT({ action: 'read_master_data' })
      .setProtectedHeader({ alg: 'HS256' })
      .setIssuer('NAMISH_ERP').setAudience('NAMISH_GLOBAL_CONTROL')
      .setIssuedAt().setExpirationTime('1m')
      .sign(secretKey);

    await withMock(makeAdminMock(), async () => {
      const res = await GET(makeReq(token));
      const data = await res.json();
      if (res.status !== 200) throw new Error('Expected 200, got ' + res.status);
      const india = data.find((c: any) => c.iso2 === 'IN');
      const us    = data.find((c: any) => c.iso2 === 'US');
      if (!india) throw new Error('India missing from result');
      if (india.supported_currencies[0] !== 'INR') throw new Error('India currency should be INR, got: ' + india.supported_currencies);
      if (!us || us.supported_currencies[0] !== 'USD') throw new Error('US currency should be USD');
    });
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

  // -- Test 3: Wrong action claim ? 403 ------------------------------------
  await test('Wrong action claim ? 403 Forbidden', async () => {
    const token = await new SignJWT({ action: 'write_data' })
      .setProtectedHeader({ alg: 'HS256' })
      .setIssuer('NAMISH_ERP').setAudience('NAMISH_GLOBAL_CONTROL')
      .setIssuedAt().setExpirationTime('1m')
      .sign(secretKey);

    const res = await GET(makeReq(token));
    const data = await res.json();
    if (res.status !== 403 || data.error !== 'Forbidden')
      throw new Error('Expected 403 Forbidden, got ' + res.status + ' ' + JSON.stringify(data));
  });

  // -- Test 4: rpc_get_country_currencies failure ? 500, no default fallback -
  await test('Mapping RPC failure ? 500, no default-currency success', async () => {
    const token = await new SignJWT({ action: 'read_master_data' })
      .setProtectedHeader({ alg: 'HS256' })
      .setIssuer('NAMISH_ERP').setAudience('NAMISH_GLOBAL_CONTROL')
      .setIssuedAt().setExpirationTime('1m')
      .sign(secretKey);

    await withMock(makeAdminMock({ currencyError: { code: '42883', message: 'function pg_catalog.coalesce...' } }), async () => {
      const res = await GET(makeReq(token));
      const data = await res.json();
      if (res.status !== 500 || data.error !== 'Internal Server Error')
        throw new Error('Expected 500 Internal Server Error, got ' + res.status + ' ' + JSON.stringify(data));
      // Must NOT have returned a successful data payload
      if (Array.isArray(data)) throw new Error('Response must not be an array on mapping failure');
    });
  });

  // -- Test 5: Expired token ? 401 -----------------------------------------
  await test('Expired token ? 401 Unauthorized', async () => {
    // exp set to 1s in the past; jwtVerify maxTokenAge='1m' rejects it
    const iat = Math.floor(Date.now() / 1000) - 120;
    const exp = iat + 1;
    const token = await new SignJWT({ action: 'read_master_data' })
      .setProtectedHeader({ alg: 'HS256' })
      .setIssuer('NAMISH_ERP').setAudience('NAMISH_GLOBAL_CONTROL')
      .setIssuedAt(iat)
      .setExpirationTime(exp)
      .sign(secretKey);

    const res = await GET(makeReq(token));
    if (res.status !== 401) throw new Error('Expected 401, got ' + res.status);
  });

  console.log('\nTests: ' + passed + ' passed, ' + failed + ' failed');
  process.exit(failed > 0 ? 1 : 0);
}
run();
