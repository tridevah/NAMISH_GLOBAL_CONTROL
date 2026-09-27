import { NextResponse } from "next/server";
import { jwtVerify } from "jose";
import { createAdminClient } from "@/utils/supabase/admin";

export async function GET(request: Request) {
  try {
    const authHeader = request.headers.get("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }
    const token = authHeader.substring(7);
    const secretStr = process.env.GLOBAL_CONTROL_HMAC_SECRET;
    if (!secretStr) return NextResponse.json({ error: "Service Unavailable" }, { status: 503 });

    let verifiedPayload: Record<string, unknown>;
    try {
      const { payload } = await jwtVerify(token, new TextEncoder().encode(secretStr), {
        algorithms: ["HS256"], issuer: "NAMISH_ERP", audience: "NAMISH_GLOBAL_CONTROL", maxTokenAge: "1m",
      });
      verifiedPayload = payload as Record<string, unknown>;
    } catch { return NextResponse.json({ error: "Unauthorized" }, { status: 401 }); }

    if (!verifiedPayload.exp || !verifiedPayload.iat) return NextResponse.json({ error: "Invalid Token Claims" }, { status: 401 });
    if (verifiedPayload.action !== "read_master_data") return NextResponse.json({ error: "Forbidden" }, { status: 403 });

    const url = new URL(request.url);
    const countryId = url.searchParams.get("country_id");
    if (!countryId) return NextResponse.json({ error: "Missing country_id" }, { status: 400 });

    const admin = createAdminClient();
    const { data, error } = await admin.rpc("rpc_get_levels", { p_country_id: countryId });
    if (error) {
      console.error("[S2S] rpc_get_levels error:", error);
      return NextResponse.json({ error: "Internal Server Error" }, { status: 500 });
    }
    return NextResponse.json(data || []);
  } catch (err) {
    console.error("[S2S] Unhandled error:", err);
    return NextResponse.json({ error: "Internal Server Error" }, { status: 500 });
  }
}
