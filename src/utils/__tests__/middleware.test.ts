import { describe, it, expect, vi } from 'vitest';
import { updateSession } from '../supabase/middleware';
import { NextRequest } from 'next/server';

vi.mock('@supabase/ssr', () => ({
  createServerClient: vi.fn().mockReturnValue({
    auth: {
      getUser: vi.fn().mockImplementation(async () => {
        // @ts-ignore
        if (global.__mockUser) return { data: { user: global.__mockUser } };
        return { data: { user: null } };
      })
    }
  })
}));

vi.mock('@supabase/supabase-js', () => ({
  createClient: vi.fn().mockReturnValue({
    rpc: vi.fn().mockImplementation(async () => {
      // @ts-ignore
      if (global.__mockStaff) return { data: global.__mockStaff, error: null };
      return { data: null, error: 'No staff' };
    })
  })
}));

describe('Middleware RBAC Logic Verification', () => {
  it('Unauthenticated -> redirects to login', async () => {
    // @ts-ignore
    global.__mockUser = null;
    const req = new NextRequest('https://control.tridevah.com/data-hub');
    const res = await updateSession(req);
    expect(res.status).toBe(307);
    expect(res.headers.get('location')).toBe('https://control.tridevah.com/login');
  });

  it('Unauthenticated API -> returns 401', async () => {
    // @ts-ignore
    global.__mockUser = null;
    const req = new NextRequest('https://control.tridevah.com/api/data-hub/countries');
    const res = await updateSession(req);
    expect(res.status).toBe(401);
  });

  it('Authorized session with correct role -> proceeds', async () => {
    // @ts-ignore
    global.__mockUser = { id: 'valid_user' };
    // @ts-ignore
    global.__mockStaff = { role: 'PLATFORM_SUPERADMIN', status: 'ACTIVE' };
    const req = new NextRequest('https://control.tridevah.com/data-hub');
    const res = await updateSession(req);
    expect(res.status).toBe(200);
  });

  it('Authorized session with insufficient role -> redirects to root', async () => {
    // @ts-ignore
    global.__mockUser = { id: 'valid_user' };
    // @ts-ignore
    global.__mockStaff = { role: 'BILLING_MANAGER', status: 'ACTIVE' };
    const req = new NextRequest('https://control.tridevah.com/data-hub');
    const res = await updateSession(req);
    expect(res.status).toBe(307);
    expect(res.headers.get('location')).toBe('https://control.tridevah.com/?error=Unauthorized_Role');
  });

  it('API route with insufficient role -> returns 403', async () => {
    // @ts-ignore
    global.__mockUser = { id: 'valid_user' };
    // @ts-ignore
    global.__mockStaff = { role: 'BILLING_MANAGER', status: 'ACTIVE' };
    const req = new NextRequest('https://control.tridevah.com/api/data-hub/countries');
    const res = await updateSession(req);
    expect(res.status).toBe(403);
  });

  it('Suspended user -> redirects to login', async () => {
    // @ts-ignore
    global.__mockUser = { id: 'valid_user' };
    // @ts-ignore
    global.__mockStaff = { role: 'PLATFORM_SUPERADMIN', status: 'SUSPENDED' };
    const req = new NextRequest('https://control.tridevah.com/data-hub');
    const res = await updateSession(req);
    expect(res.status).toBe(307);
    expect(res.headers.get('location')).toBe('https://control.tridevah.com/login?error=Unauthorized');
  });
});
