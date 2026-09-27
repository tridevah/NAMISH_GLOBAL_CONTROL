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

    const levelId = url.searchParams.get("level_id") || null;
    const parentId = url.searchParams.get("parent_id") || null;
    
    const admin = createAdminClient();

    if (parentId) {
      if (!levelId) {
        return NextResponse.json({ error: "Parent supplied without levelId" }, { status: 400 });
      }

      // Hierarchy lookup using authorized RPC
      const { data: allLevels, error: levelsErr } = await admin.rpc("rpc_get_levels", { p_country_id: countryId });
      
      if (levelsErr || !allLevels || allLevels.length === 0) {
        return NextResponse.json({ error: "Hierarchy lookup error" }, { status: 503 });
      }

      const targetIndex = allLevels.findIndex((l: any) => l.id === levelId);
      if (targetIndex === -1) {
        return NextResponse.json({ error: "Invalid target level" }, { status: 400 });
      }
      if (targetIndex === 0) {
        return NextResponse.json({ error: "Top-level target cannot have a parent" }, { status: 400 });
      }
      
      const expectedParentLevelId = allLevels[targetIndex - 1].id;

      // Parent lookup - relying on public view as no rpc_get_unit exists
      const { data: parentUnit, error: parentErr } = await admin
        .from("geography_units")
        .select("country_id, geography_level_id")
        .eq("id", parentId)
        .maybeSingle();
        
      if (parentErr) {
        return NextResponse.json({ error: "Parent lookup failure" }, { status: 503 });
      }
      if (!parentUnit) {
        return NextResponse.json({ error: "Parent genuinely absent" }, { status: 400 });
      }
      
      if (parentUnit.country_id !== countryId) {
        return NextResponse.json({ error: "Cross-country parent reference rejected" }, { status: 400 });
      }
      if (parentUnit.geography_level_id !== expectedParentLevelId) {
        return NextResponse.json({ error: "Invalid hierarchy level for parent" }, { status: 400 });
      }
    }

    const status = url.searchParams.get("status") || null;
    const search = url.searchParams.get("search") || null;
    const limit = parseInt(url.searchParams.get("limit") || "200", 10);
    const offset = parseInt(url.searchParams.get("offset") || "0", 10);

    const { data, error } = await admin.rpc("rpc_get_units", {
      p_country_id: countryId,
      p_level_id: levelId,
      p_parent_id: parentId,
      p_status: status,
      p_search: search,
      p_limit: limit,
      p_offset: offset
    });

    if (error) {
      console.error("[S2S] rpc_get_units error:", error);
      return NextResponse.json({ error: "Internal Server Error" }, { status: 500 });
    }
    return NextResponse.json(data || { rows: [], total: 0 });
  } catch (err) {
    console.error("[S2S] Unhandled error:", err);
    return NextResponse.json({ error: "Internal Server Error" }, { status: 500 });
  }
}
