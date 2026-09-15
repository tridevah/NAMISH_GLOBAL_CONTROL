import { NextResponse } from "next/server";
import { jwtVerify, type JWTPayload } from "jose";
import { createAdminClient } from '@/utils/supabase/admin';


/** Custom claims carried in the ERP-issued S2S JWT. */
interface S2SPayload extends JWTPayload {
  email?: string;
  full_name?: string;
  idempotency_key?: string;
  erp_app_user_id?: string;
}

export async function POST(request: Request) {

  try {
    const supabaseAdmin = createAdminClient();
  const authHeader = request.headers.get("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return NextResponse.json({ error: "Missing or invalid Authorization header" }, { status: 401 });
    }

    const token = authHeader.substring(7);
    const secretStr = process.env.GLOBAL_CONTROL_HMAC_SECRET;
    if (!secretStr) {
      return NextResponse.json({ error: "S2S Configuration Missing" }, { status: 503 });
    }

    const secretKey = new TextEncoder().encode(secretStr);
    let payload: S2SPayload;
    try {
      const { payload: raw } = await jwtVerify<S2SPayload>(token, secretKey, {
        issuer: "NAMISH_ERP",
        audience: "NAMISH_GLOBAL_CONTROL",
        algorithms: ["HS256"],
        maxTokenAge: "5m",
      });
      payload = raw;
    } catch {
      return NextResponse.json({ error: "Invalid S2S Token" }, { status: 401 });
    }

    // The signed JWT is the sole request authority.
    // Body is never parsed to prevent duplicate-field injection.
    const { jti, email, full_name: fullName, idempotency_key: idempotencyKey, erp_app_user_id: erpAppUserId, exp } = payload;

    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (!jti || !email || !idempotencyKey || !erpAppUserId || !fullName || !exp) {
      return NextResponse.json({ error: "Malformed payload: missing required claims" }, { status: 400 });
    }
    if (!uuidRegex.test(jti) || !uuidRegex.test(erpAppUserId)) {
      return NextResponse.json({ error: "Malformed payload: invalid UUID format" }, { status: 400 });
    }

    // Reject JWT replay. s2s_reject_if_jwt_replay inserts jti; throws 23505 on duplicate.
    const tokenExpAt = new Date(exp * 1000).toISOString();
    const { error: replayError } = await supabaseAdmin.rpc("s2s_reject_if_jwt_replay", {
      p_jti: jti,
      p_issuer: "NAMISH_ERP",
      p_audience: "NAMISH_GLOBAL_CONTROL",
      p_token_exp: tokenExpAt,
    });

    if (replayError) {
      if (replayError?.code === "42883" || replayError?.code === "PGRST202" || replayError.message?.includes('Could not find the function')) {
        return NextResponse.json({ error: "SCHEMA_MISSING: s2s_reject_if_jwt_replay not provisioned" }, { status: 503 });
      }
      if (replayError.code === "23505") {
        return NextResponse.json({ error: "Replay Detected: This S2S token has already been used." }, { status: 409 });
      }
      return NextResponse.json({ error: "Replay check failed" }, { status: 500 });
    }

    // Atomically provision the enterprise with advisory-lock serialization.
    const { data, error } = await supabaseAdmin.rpc("s2s_provision_enterprise_atomic", {
      p_email: email,
      p_full_name: fullName,
      p_idempotency_key: idempotencyKey,
      p_erp_app_user_id: erpAppUserId,
    }).single();

    if (error) {
      if (error.code === "42883" || error?.code === "PGRST202" || error.message?.includes('Could not find the function')) {
        return NextResponse.json({ error: "SCHEMA_MISSING: s2s_provision_enterprise_atomic not provisioned" }, { status: 503 });
      }
      if (error.code === "23514") {
        // Immutable field conflict: provisioned email or name does not match stored values
        return NextResponse.json({ error: "Conflict: " + error.message }, { status: 409 });
      }
      if (error.code === "55P03") {
        // lock_timeout from advisory lock
        return NextResponse.json({ error: "Service temporarily unavailable. Please retry." }, { status: 503 });
      }
      console.error("[S2S Provision Enterprise] DB error:", error);
      return NextResponse.json({ error: "Database operation failed" }, { status: 500 });
    }

        const rpcResponse = data as { platform_account_id?: string } | null;
    if (!rpcResponse?.platform_account_id) {
      return NextResponse.json({ error: "SCHEMA_MISSING: RPC returned no platform_account_id" }, { status: 503 });
    }

    return NextResponse.json({ platformAccountId: rpcResponse.platform_account_id });
  } catch (e) {
    console.error("[S2S Provision Enterprise Error]:", e);
    return NextResponse.json({ error: "Internal Server Error" }, { status: 500 });
  }
}








