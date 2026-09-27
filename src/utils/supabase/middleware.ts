import { createServerClient } from '@supabase/ssr'
import { NextResponse, type NextRequest } from 'next/server'

export async function updateSession(request: NextRequest) {
  // S2S routes are authenticated by their own route handlers via HMAC signatures.
  const isS2SProvision = request.method === 'POST' && request.nextUrl.pathname === '/api/s2s/provision-enterprise';
  const isS2SCountries = request.method === 'GET' && request.nextUrl.pathname === '/api/s2s/master-data/countries';
  const isS2SLevels = request.method === 'GET' && request.nextUrl.pathname === '/api/s2s/master-data/geography/levels';
  const isS2SGeoUnits = request.method === 'GET' && request.nextUrl.pathname === '/api/s2s/master-data/geography/units';
  const isS2SUnits = request.method === 'GET' && request.nextUrl.pathname === '/api/s2s/master-data/units';
  const isS2STaxes = request.method === 'GET' && request.nextUrl.pathname === '/api/s2s/master-data/taxes';
  
  if (isS2SProvision || isS2SCountries || isS2SLevels || isS2SGeoUnits || isS2SUnits || isS2STaxes) {
    return NextResponse.next()
  }

  let supabaseResponse = NextResponse.next({
    request,
  })

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll()
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value))
          supabaseResponse = NextResponse.next({
            request,
          })
          cookiesToSet.forEach(({ name, value, options }) =>
            supabaseResponse.cookies.set(name, value, options)
          )
        },
      },
    }
  )

  const {
    data: { user },
  } = await supabase.auth.getUser()

  // Public routes: login page, all /api/auth/* endpoints, health check.
  const isPublicRoute =
    request.nextUrl.pathname === '/login' ||
    request.nextUrl.pathname.startsWith('/api/auth/') ||
    request.nextUrl.pathname.startsWith('/api/health')

  if (!user && !isPublicRoute) {
    if (request.nextUrl.pathname.startsWith('/api/')) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }
    const url = request.nextUrl.clone()
    url.pathname = '/login'
    return NextResponse.redirect(url)
  }

  if (user && request.nextUrl.pathname === '/login') {
    return NextResponse.redirect(new URL('/', request.url))
  }

  return supabaseResponse
}
