// @vitest-environment node
import { POST } from '../route';
import { vi, describe, it, expect, beforeEach } from 'vitest';
import { jwtVerify } from 'jose';

const { mockRpc } = vi.hoisted(() => ({ mockRpc: vi.fn() }));

vi.mock('jose', () => ({
    jwtVerify: vi.fn()
}));

vi.mock('@/utils/supabase/admin', () => ({
    createAdminClient: vi.fn(() => ({ rpc: mockRpc }))
}));

describe('GC Route F01, F04, F09 Regressions', () => {
    beforeEach(() => {
        process.env.GLOBAL_CONTROL_HMAC_SECRET = 'secret';
        vi.clearAllMocks();
    });

    it('F01: Provisions ERP correctly', async () => {
        vi.mocked(jwtVerify).mockResolvedValue({
            payload: {
                jti: '123e4567-e89b-12d3-a456-426614174000',
                email: 'test@test.com',
                full_name: 'test',
                idempotency_key: 'key',
                erp_app_user_id: '123e4567-e89b-12d3-a456-426614174001',
                exp: 9999999999
            },
            protectedHeader: { alg: 'HS256' }
        });
        
        mockRpc.mockResolvedValueOnce({ error: null }); // s2s_reject_if_jwt_replay
        mockRpc.mockReturnValueOnce({ single: vi.fn().mockResolvedValue({ error: null, data: { platform_account_id: 'plat123' } }) });

        const req = new Request('http://localhost', {
            method: 'POST',
            headers: { 'Authorization': 'Bearer testtoken' }
        });

        const res = await POST(req);
        expect(res.status).toBe(200);
        const json = await res.json();
        expect(json.platformAccountId).toBe('plat123');
        expect(mockRpc).toHaveBeenCalledTimes(2);
    });

    it('F09: Maps errors properly', async () => {
        const req = new Request('http://localhost', {
            method: 'POST',
            headers: { 'Authorization': 'Bearer token' }
        });

        vi.mocked(jwtVerify).mockResolvedValue({
            payload: {
                jti: '123e4567-e89b-12d3-a456-426614174000',
                email: 'test@test.com',
                full_name: 'test',
                idempotency_key: 'key',
                erp_app_user_id: '123e4567-e89b-12d3-a456-426614174001',
                exp: 9999999999
            },
            protectedHeader: { alg: 'HS256' }
        });

        // s2s_reject_if_jwt_replay
        mockRpc.mockResolvedValueOnce({ error: { code: '23505' } });
        let res = await POST(req);
        expect(res.status).toBe(409);
        expect((await res.json()).error).toMatch(/Replay Detected/);

        // Reset mock
        mockRpc.mockReset();
        mockRpc.mockResolvedValueOnce({ error: null }); // reject_if_jwt_replay passes
        mockRpc.mockReturnValueOnce({ single: vi.fn().mockResolvedValue({ error: { code: '23514', message: 'Immutable field' } }) });
        
        req.headers.set('Authorization', 'Bearer token2');
        res = await POST(req);
        expect(res.status).toBe(409);
        expect((await res.json()).error).toMatch(/Immutable field/);

        // Reset mock
        mockRpc.mockReset();
        mockRpc.mockResolvedValueOnce({ error: null });
        mockRpc.mockReturnValueOnce({ single: vi.fn().mockResolvedValue({ error: { code: '55P03' } }) });
        
        req.headers.set('Authorization', 'Bearer token3');
        res = await POST(req);
        expect(res.status).toBe(503);
    });

    it('F04: Rejects if missing Auth header', async () => {
        const req = new Request('http://localhost', { method: 'POST' });
        const res = await POST(req);
        expect(res.status).toBe(401);
    });
});


