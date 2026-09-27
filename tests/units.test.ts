import { describe, it, expect, vi } from 'vitest';
import { GET } from '../src/app/api/data-hub/units/route';
import { NextRequest } from 'next/server';

// Mock getAuthContext and createAdminClient
vi.mock('@/utils/auth', () => ({
    getAuthContext: vi.fn()
}));

vi.mock('@/utils/supabase/admin', () => ({
    createAdminClient: vi.fn()
}));

import { getAuthContext } from '@/utils/auth';
import { createAdminClient } from '@/utils/supabase/admin';

describe('Data Hub Units API Handler', () => {
    it('should reject unauthorized access', async () => {
        vi.mocked(getAuthContext).mockResolvedValue({ staff: null } as any);
        const req = new NextRequest('http://localhost:3000/api/data-hub/units');
        const res = await GET(req);
        expect(res.status).toBe(403);
        const body = await res.json();
        expect(body.error).toContain('Unauthorized Access');
    });

    it('should return sanitized error on DB failure (simulating unapplied migration)', async () => {
        vi.mocked(getAuthContext).mockResolvedValue({ staff: { id: 'staff1' } } as any);
        
        const mockQuery = {
            select: vi.fn().mockReturnThis(),
            or: vi.fn().mockReturnThis(),
            eq: vi.fn().mockReturnThis(),
            order: vi.fn().mockReturnThis(),
            range: vi.fn().mockResolvedValue({ data: null, count: null, error: { message: 'relation "public.measurement_units" does not exist' } })
        };
        
        vi.mocked(createAdminClient).mockReturnValue({
            from: vi.fn().mockReturnValue(mockQuery)
        } as any);

        const req = new NextRequest('http://localhost:3000/api/data-hub/units?page=1&search=kg');
        const res = await GET(req);
        
        expect(res.status).toBe(503); // Service temporarily unavailable
        const body = await res.json();
        expect(body.error).toContain('verify pending migrations');
    });

    it('should return paginated data on successful DB query', async () => {
        vi.mocked(getAuthContext).mockResolvedValue({ staff: { id: 'staff1' } } as any);
        
        const mockData = [{ id: '1', name: 'Kilogram', symbol: 'kg', status: 'ACTIVE' }];
        const mockQuery = {
            select: vi.fn().mockReturnThis(),
            or: vi.fn().mockReturnThis(),
            eq: vi.fn().mockReturnThis(),
            order: vi.fn().mockReturnThis(),
            range: vi.fn().mockResolvedValue({ data: mockData, count: 1, error: null })
        };
        
        vi.mocked(createAdminClient).mockReturnValue({
            from: vi.fn().mockReturnValue(mockQuery)
        } as any);

        const req = new NextRequest('http://localhost:3000/api/data-hub/units?limit=50&offset=0');
        const res = await GET(req);
        
        expect(res.status).toBe(200);
        const body = await res.json();
        expect(body.data).toEqual(mockData);
        expect(body.count).toBe(1);
    });
});
