import { describe, it, expect, vi, beforeEach } from 'vitest';
import { GET } from './route';

vi.mock('jose', () => ({
    jwtVerify: vi.fn().mockResolvedValue({
        payload: { exp: Date.now() / 1000 + 3600, iat: Date.now() / 1000, action: 'read_master_data' }
    })
}));

const mockRpc = vi.fn();
const mockMaybeSingle = vi.fn();
const mockEq = vi.fn().mockReturnValue({ maybeSingle: mockMaybeSingle });
const mockSelect = vi.fn().mockReturnValue({ eq: mockEq });
const mockFrom = vi.fn().mockReturnValue({ select: mockSelect });

vi.mock('@/utils/supabase/admin', () => ({
    createAdminClient: () => ({
        from: mockFrom,
        rpc: mockRpc
    })
}));

process.env.GLOBAL_CONTROL_HMAC_SECRET = 'test-secret';

describe('GC Units S2S Handler', () => {
    beforeEach(() => {
        vi.clearAllMocks();
    });

    const mockRequest = (url: string) => {
        return new Request(url, {
            method: 'GET',
            headers: { 'Authorization': 'Bearer valid-token' }
        });
    };

    it('1. Parent supplied without levelId -> 400', async () => {
        const req = mockRequest('http://localhost/api/s2s/master-data/geography/units?country_id=country1&parent_id=parent1');
        const res = await GET(req);
        expect(res.status).toBe(400);
        expect(mockRpc).not.toHaveBeenCalled();
    });

    it('2. Hierarchy lookup error -> 503', async () => {
        mockRpc.mockImplementation(async (rpcName) => {
            if (rpcName === 'rpc_get_levels') return { data: null, error: new Error('DB Error') };
            return { data: null, error: null };
        });
        const req = mockRequest('http://localhost/api/s2s/master-data/geography/units?country_id=country1&level_id=lvl2&parent_id=parent1');
        const res = await GET(req);
        expect(res.status).toBe(503);
        expect(mockRpc).toHaveBeenCalledTimes(1); // Only for levels, not units listing
    });

    it('3. targetIndex === -1 -> 400', async () => {
        mockRpc.mockImplementation(async (rpcName) => {
            if (rpcName === 'rpc_get_levels') return { data: [{id: 'lvl1'}], error: null };
            return { data: null, error: null };
        });
        const req = mockRequest('http://localhost/api/s2s/master-data/geography/units?country_id=country1&level_id=unknown_lvl&parent_id=parent1');
        const res = await GET(req);
        expect(res.status).toBe(400);
        const data = await res.json();
        expect(data.error).toBe('Invalid target level');
    });

    it('4. Top-level target with parent -> 400', async () => {
        mockRpc.mockImplementation(async (rpcName) => {
            if (rpcName === 'rpc_get_levels') return { data: [{id: 'lvl1'}], error: null };
            return { data: null, error: null };
        });
        const req = mockRequest('http://localhost/api/s2s/master-data/geography/units?country_id=country1&level_id=lvl1&parent_id=parent1');
        const res = await GET(req);
        expect(res.status).toBe(400);
    });

    it('5. Parent lookup failure -> 503', async () => {
        mockRpc.mockImplementation(async (rpcName) => {
            if (rpcName === 'rpc_get_levels') return { data: [{id: 'lvl1'}, {id: 'lvl2'}], error: null };
            return { data: null, error: null };
        });
        mockMaybeSingle.mockResolvedValue({ data: null, error: new Error('Lookup Failed') });

        const req = mockRequest('http://localhost/api/s2s/master-data/geography/units?country_id=country1&level_id=lvl2&parent_id=parent1');
        const res = await GET(req);
        expect(res.status).toBe(503);
    });

    it('6. Parent genuinely absent -> 400', async () => {
        mockRpc.mockImplementation(async (rpcName) => {
            if (rpcName === 'rpc_get_levels') return { data: [{id: 'lvl1'}, {id: 'lvl2'}], error: null };
            return { data: null, error: null };
        });
        mockMaybeSingle.mockResolvedValue({ data: null, error: null });

        const req = mockRequest('http://localhost/api/s2s/master-data/geography/units?country_id=country1&level_id=lvl2&parent_id=parent1');
        const res = await GET(req);
        expect(res.status).toBe(400);
    });

    it('7. Cross-country parent -> 400', async () => {
        mockRpc.mockImplementation(async (rpcName) => {
            if (rpcName === 'rpc_get_levels') return { data: [{id: 'lvl1'}, {id: 'lvl2'}], error: null };
            return { data: null, error: null };
        });
        mockMaybeSingle.mockResolvedValue({ data: { country_id: 'other', geography_level_id: 'lvl1' }, error: null });

        const req = mockRequest('http://localhost/api/s2s/master-data/geography/units?country_id=country1&level_id=lvl2&parent_id=parent1');
        const res = await GET(req);
        expect(res.status).toBe(400);
    });

    it('8. Parent of incorrect adjacent level -> 400', async () => {
        mockRpc.mockImplementation(async (rpcName) => {
            if (rpcName === 'rpc_get_levels') return { data: [{id: 'lvl1'}, {id: 'lvl2'}, {id: 'lvl3'}], error: null };
            return { data: null, error: null };
        });
        mockMaybeSingle.mockResolvedValue({ data: { country_id: 'country1', geography_level_id: 'lvl1' }, error: null });

        // Requesting lvl3 but parent is lvl1 instead of expected lvl2
        const req = mockRequest('http://localhost/api/s2s/master-data/geography/units?country_id=country1&level_id=lvl3&parent_id=parent1');
        const res = await GET(req);
        expect(res.status).toBe(400);
        const data = await res.json();
        expect(data.error).toBe('Invalid hierarchy level for parent');
    });

    it('9. Valid parent -> successful listing', async () => {
        mockRpc.mockImplementation(async (rpcName) => {
            if (rpcName === 'rpc_get_levels') return { data: [{id: 'lvl1'}, {id: 'lvl2'}], error: null };
            if (rpcName === 'rpc_get_units') return { data: { rows: ['unit1'] }, error: null };
            return { data: null, error: null };
        });
        mockMaybeSingle.mockResolvedValue({ data: { country_id: 'country1', geography_level_id: 'lvl1' }, error: null });

        const req = mockRequest('http://localhost/api/s2s/master-data/geography/units?country_id=country1&level_id=lvl2&parent_id=parent1');
        const res = await GET(req);
        expect(res.status).toBe(200);
        expect(mockRpc).toHaveBeenCalledTimes(2); // One for levels, one for units
    });

    it('10. ParentId absent -> successful listing', async () => {
        mockRpc.mockImplementation(async (rpcName) => {
            if (rpcName === 'rpc_get_units') return { data: { rows: ['unit1'] }, error: null };
            return { data: null, error: null };
        });

        const req = mockRequest('http://localhost/api/s2s/master-data/geography/units?country_id=country1');
        const res = await GET(req);
        expect(res.status).toBe(200);
        // Should only call rpc_get_units, not rpc_get_levels
        expect(mockRpc).toHaveBeenCalledTimes(1); 
    });
});
