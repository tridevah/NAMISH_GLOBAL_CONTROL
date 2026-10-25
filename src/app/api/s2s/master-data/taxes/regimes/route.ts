import { NextRequest, NextResponse } from 'next/server';
import { jwtVerify } from "jose";
import { createAdminClient } from '@/utils/supabase/admin';

export async function GET(req: NextRequest) {
    try {
        const authHeader = req.headers.get("Authorization");
        if (!authHeader || !authHeader.startsWith("Bearer ")) {
            return NextResponse.json({ error: "Unauthorized", details: "No Auth Header" }, { status: 401 });
        }

        const token = authHeader.substring(7);
        const secretStr = process.env.GLOBAL_CONTROL_HMAC_SECRET || process.env.HMAC_SECRET;
        if (!secretStr) {
            console.error("[S2S] GLOBAL_CONTROL_HMAC_SECRET not configured");
            return NextResponse.json({ error: "Service Unavailable" }, { status: 503 });
        }

        const secretKey = new TextEncoder().encode(secretStr);
        let verifiedPayload: Record<string, unknown>;
        try {
            const { payload } = await jwtVerify(token, secretKey, {
                algorithms: ["HS256"],
                issuer: "NAMISH_ERP",
                audience: "NAMISH_GLOBAL_CONTROL",
                maxTokenAge: "1m",
            });
            verifiedPayload = payload as Record<string, unknown>;
        } catch (e: any) {
            console.error('>>> JWT Verify Error:', e);
            return NextResponse.json({ error: "Unauthorized", details: e.message || String(e) }, { status: 401 });
        }

        if (!verifiedPayload.exp || !verifiedPayload.iat) {
            return NextResponse.json({ error: "Invalid Token Claims" }, { status: 401 });
        }

        if (verifiedPayload.action !== "read_master_data") {
            return NextResponse.json({ error: "Forbidden" }, { status: 403 });
        }

        const { searchParams } = new URL(req.url);
        const countryId = searchParams.get('countryId');

        if (!countryId) {
            return NextResponse.json({ error: 'Missing countryId parameter' }, { status: 400 });
        }

        const admin = createAdminClient();

        // Fetch coverage first
        const { data: coverage, error: coverageError } = await admin
            .from('country_tax_coverage')
            .select('status')
            .eq('country_id', countryId)
            .single();

        if (coverageError && coverageError.code !== 'PGRST116') {
            throw coverageError;
        }

        const { data: regimes, error: regimesError } = await admin
            .from('tax_regimes')
            .select('id, code, name, status, effective_from')
            .eq('country_id', countryId)
            .eq('status', 'ACTIVE');

        if (regimesError) {
            throw regimesError;
        }

        return NextResponse.json({
            success: true,
            data: {
                coverageStatus: coverage ? coverage.status : 'UNRESOLVED',
                regimes: regimes || []
            }
        });
    } catch (e: any) {
        console.error('[GC Tax Regimes API] Error:', e);
        return NextResponse.json({ error: e.message || 'Internal Server Error' }, { status: 500 });
    }
}
