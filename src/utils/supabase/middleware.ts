import { createServerClient } from '@supabase/ssr'
import { NextResponse, type NextRequest } from 'next/server'
import { createClient } from '@supabase/supabase-js'

function getRoleFromPath(pathname: string): string[] | null {
  if (pathname.startsWith('/billing')) return ['PLATFORM_SUPERADMIN', 'BILLING_MANAGER']
  if (pathname.startsWith('/accounts')) return ['PLATFORM_SUPERADMIN', 'SUPPORT_AUDITOR']
  if (pathname.startsWith('/tenant-registry')) return ['PLATFORM_SUPERADMIN', 'SUPPORT_AUDITOR']
  if (pathname.startsWith('/audit')) return ['PLATFORM_SUPERADMIN', 'SUPPORT_AUDITOR']
  if (pathname.startsWith('/data-hub') || pathname.startsWith('/api/data-hub')) return ['PLATFORM_SUPERADMIN', 'CATALOG_MANAGER', 'SUPPORT_AUDITOR']
  return null // No specific role restriction beyond ACTIVE
}

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

  let supabaseResponse = NextResponse.next({ request })

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() { return request.cookies.getAll() },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value))
          supabaseResponse = NextResponse.next({ request })
          cookiesToSet.forEach(({ name, value, options }) =>
            supabaseResponse.cookies.set(name, value, options)
          )
        },
      },
    }
  )

  const { data: { user } } = await supabase.auth.getUser()

  const isPublicRoute =
    request.nextUrl.pathname === '/login' ||
    request.nextUrl.pathname.startsWith('/api/auth/') ||
    request.nextUrl.pathname.startsWith('/api/health') ||
    request.nextUrl.pathname.startsWith('/_next') ||
    request.nextUrl.pathname === '/favicon.ico'

  if (!user && !isPublicRoute) {
    if (request.nextUrl.pathname.startsWith('/api/')) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }
    const url = request.nextUrl.clone()
    url.pathname = '/login'
    return NextResponse.redirect(url)
  }

  if (user && !isPublicRoute) {
    // Fetch staff authority for role-based access control
    const adminSupabase = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!,
      { auth: { autoRefreshToken: false, persistSession: false } }
    )
    const { data: staff, error: rpcError } = await adminSupabase.rpc('resolve_platform_staff_authority', {
      p_auth_user_id: user.id
    })

    if (rpcError || !staff || staff.status !== 'ACTIVE') {
      if (request.nextUrl.pathname.startsWith('/api/')) {
        return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
      }
      return NextResponse.redirect(new URL('/login?error=Unauthorized', request.url))
    }

    const allowedRoles = getRoleFromPath(request.nextUrl.pathname)
    if (allowedRoles && !allowedRoles.includes(staff.role)) {
      if (request.nextUrl.pathname.startsWith('/api/')) {
        return NextResponse.json({ error: 'Forbidden: Insufficient Role' }, { status: 403 })
      }
      return NextResponse.redirect(new URL('/?error=Unauthorized_Role', request.url))
    }
  }

  if (user && request.nextUrl.pathname === '/login') {
    return NextResponse.redirect(new URL('/', request.url))
  }

  return supabaseResponse
}
