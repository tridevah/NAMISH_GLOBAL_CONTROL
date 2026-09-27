import { describe, it, expect, vi } from 'vitest';
import { getAuthContext } from '../auth';

vi.mock('@/utils/supabase/server', () => ({
  createClient: vi.fn().mockResolvedValue({
    auth: {
      getUser: vi.fn().mockResolvedValue({ data: { user: { id: 'user_1' } } })
    }
  })
}));

vi.mock('@/utils/supabase/admin', () => ({
  createAdminClient: vi.fn().mockReturnValue({
    rpc: vi.fn().mockImplementation(async (rpcName, params) => {
      // @ts-ignore
      if (global.__mockStaff) {
        // @ts-ignore
        return { data: global.__mockStaff, error: null };
      }
      return { data: null, error: 'No staff' };
    })
  })
}));

// Mock react cache
vi.mock('react', () => ({
  cache: (fn: any) => fn
}));
vi.mock('next/navigation', () => ({
  redirect: vi.fn()
}));

describe('Auth Logic Verification', () => {
  it('Authorized session -> dashboard renders (auth context returns staff)', async () => {
    // @ts-ignore
    global.__mockStaff = { role: 'PLATFORM_SUPERADMIN', status: 'ACTIVE' };
    const ctx = await getAuthContext();
    expect(ctx.user).toBeTruthy();
    expect(ctx.staff.role).toBe('PLATFORM_SUPERADMIN');
    expect(ctx.error).toBeNull();
  });

  it('Inactive user -> denied', async () => {
    // @ts-ignore
    global.__mockStaff = { role: 'PLATFORM_SUPERADMIN', status: 'SUSPENDED' };
    const ctx = await getAuthContext();
    expect(ctx.staff).toBeNull();
    expect(ctx.error).toBe('UNAUTHORIZED');
  });

  it('Insufficient role user -> denied (handled by page logic, but auth returns role)', async () => {
    // @ts-ignore
    global.__mockStaff = { role: 'SUPPORT_AUDITOR', status: 'ACTIVE' };
    const ctx = await getAuthContext();
    expect(ctx.staff.role).toBe('SUPPORT_AUDITOR');
  });
});
