// Test: Does the real Supabase project expose 'catalog' schema via PostgREST?
const https = require('https')
const fs = require('fs')

const env = {}
fs.readFileSync('.env.local', 'utf8').split('\n').forEach(l => {
  const eq = l.indexOf('='); if (eq > 0 && !l.startsWith('#')) env[l.substring(0,eq).trim()] = l.substring(eq+1).trim()
})

const URL_BASE = env.NEXT_PUBLIC_SUPABASE_URL
const KEY = env.SUPABASE_SERVICE_ROLE_KEY

function request(schema, path, params = {}) {
  return new Promise((resolve) => {
    const host = new URL(URL_BASE).hostname
    const qs = Object.entries(params).map(([k,v]) => `${k}=${encodeURIComponent(v)}`).join('&')
    const fullPath = `/rest/v1/${path}${qs ? '?' + qs : ''}`
    const opts = {
      hostname: host,
      path: fullPath,
      method: 'GET',
      headers: {
        'apikey': KEY,
        'Authorization': `Bearer ${KEY}`,
        'Accept': 'application/json',
        ...(schema !== 'public' ? { 'Accept-Profile': schema } : {})
      }
    }
    const req = https.get(opts, res => {
      let body = ''; res.on('data', c => body += c)
      res.on('end', () => resolve({ status: res.statusCode, body: body.substring(0, 300) }))
    })
    req.on('error', e => resolve({ status: 'ERR', body: e.message }))
  })
}

async function main() {
  console.log('=== Testing schema exposure ===\n')
  
  // Test public schema
  const pub = await request('public', 'countries', { select: 'id', limit: '1' })
  console.log('public.countries:', pub.status, pub.body.substring(0,100))
  
  // Test catalog schema  
  const cat = await request('catalog', 'countries', { select: 'id,iso2', limit: '1' })
  console.log('catalog.countries:', cat.status, cat.body.substring(0,200))
  
  const catTA = await request('catalog', 'tax_authorities', { select: 'id,authority_name', limit: '1' })
  console.log('catalog.tax_authorities:', catTA.status, catTA.body.substring(0,200))
  
  const catTR = await request('catalog', 'tax_regimes', { select: 'id,code', limit: '1' })
  console.log('catalog.tax_regimes:', catTR.status, catTR.body.substring(0,200))

  // Test what the JS client actually does - check if 'db' option helps
  const noSchema = await request('public', 'tax_authorities', { select: 'id', limit: '1' })
  console.log('\npublic.tax_authorities (no schema header):', noSchema.status, noSchema.body.substring(0,200))
}
main()
