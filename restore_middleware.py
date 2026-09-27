import re
filepath = r"src\utils\supabase\middleware.ts"
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

old_block = """  // This exact S2S POST is authenticated by its route handler.
  if (
    request.method === 'POST' &&
    request.nextUrl.pathname === '/api/s2s/provision-enterprise'
  ) {
    return NextResponse.next()
  }"""

new_block = """  // S2S routes are authenticated by their own route handlers via HMAC signatures.
  const isS2SProvision = request.method === 'POST' && request.nextUrl.pathname === '/api/s2s/provision-enterprise';
  const isS2SCountries = request.method === 'GET' && request.nextUrl.pathname === '/api/s2s/master-data/countries';
  const isS2SLevels = request.method === 'GET' && request.nextUrl.pathname === '/api/s2s/master-data/geography/levels';
  const isS2SGeoUnits = request.method === 'GET' && request.nextUrl.pathname === '/api/s2s/master-data/geography/units';
  const isS2SUnits = request.method === 'GET' && request.nextUrl.pathname === '/api/s2s/master-data/units';
  
  if (isS2SProvision || isS2SCountries || isS2SLevels || isS2SGeoUnits || isS2SUnits) {
    return NextResponse.next()
  }"""

if old_block in content:
    content = content.replace(old_block, new_block)
else:
    print("Warning: old_block not found in middleware")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print("Restored S2S middleware exemptions.")
