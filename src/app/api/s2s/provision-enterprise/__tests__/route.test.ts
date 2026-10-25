import { describe, it, expect, vi, beforeEach } from 'vitest';
import { POST } from '../route';
import * as admin from '@/utils/supabase/admin';
import * as jose from 'jose';

vi.mock('@/utils/supabase/admin', () => ({
    createAdminClient: vi.fn()
}));

describe('GC Provision Enterprise S2S Route', () => {
    let mockRpc: any;
    
    beforeEach(() => {
        process.env.GLOBAL_CONTROL_HMAC_SECRET = 'super-secret-key-that-is-long-enough-32-bytes!';
        mockRpc = vi.fn();
        (admin.createAdminClient as any).mockReturnValue({ rpc: mockRpc });
        vi.clearAllMocks();
    });

    const createRequest = async (payload: any, token?: string) => {
        let authHeader = token ? `Bearer ${token}` : undefined;
        if (token === 'GENERATE') {
            const secret = new TextEncoder().encode(process.env.GLOBAL_CONTROL_HMAC_SECRET);
            authHeader = 'Bearer ' + await new jose.SignJWT({ email: payload.email, full_name: payload.fullName, idempotency_key: payload.idempotencyKey, erp_app_user_id: payload.erpAppUserId })
                .setProtectedHeader({ alg: 'HS256' })
                .setIssuedAt()
                .setJti('11111111-1111-1111-1111-111111111111')
                .setIssuer('NAMISH_ERP')
                .setAudience('NAMISH_GLOBAL_CONTROL')
                .setExpirationTime('1m')
                .sign(secret);
        }

        const req = new Request('http://localhost/api/s2s/provision-enterprise', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                ...(authHeader ? { 'Authorization': authHeader } : {})
            },
            body: JSON.stringify(payload)
        });
        return req;
    };

    it('rejects missing or invalid JWT', async () => {
        const req = await createRequest({ email: 'test@example.com' });
        const res = await POST(req);
        expect(res.status).toBe(401);
    });

    it('handles schema missing error during replay check natively', async () => {
        mockRpc.mockResolvedValueOnce({ error: { code: '42883' } }); // schema missing

        const req = await createRequest({ email: 'test@example.com', idempotencyKey: 'k1', fullName: 'F', erpAppUserId: '22222222-2222-2222-2222-222222222222' }, 'GENERATE');
        const res = await POST(req);
        
        expect(res.status).toBe(503);
        const data = await res.json();
        expect(data.error).toMatch(/SCHEMA_MISSING/i);
    });

    it('handles unique violation during provisioning natively', async () => {
        mockRpc.mockResolvedValueOnce({ error: null }); // replay check pass
        // Next rpc call for provision
        mockRpc.mockReturnValueOnce({ single: vi.fn().mockResolvedValue({ error: { code: '23514', message: 'Immutable field mismatch' } }) });

        const req = await createRequest({ email: 'test@example.com', idempotencyKey: 'k2', fullName: 'F', erpAppUserId: '33333333-3333-3333-3333-333333333333' }, 'GENERATE');
        const res = await POST(req);
        
        expect(res.status).toBe(409);
        const data = await res.json();
        expect(data.error).toMatch(/Conflict/i);
    });
});
