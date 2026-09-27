import { NextResponse } from "next/server";
import { jwtVerify } from "jose";
import { createAdminClient } from "@/utils/supabase/admin";

/**
 * S2S GET /api/s2s/master-data/countries
 *
 * Machine-to-machine endpoint consumed by NAMISH_ERP to read the authoritative
 * country + default-currency mapping from Global Control.
 *
 * Auth: HS256 JWT signed with GLOBAL_CONTROL_HMAC_SECRET
 *   - iss: NAMISH_ERP
 *   - aud: NAMISH_GLOBAL_CONTROL
 *   - action: read_master_data
 *   - exp required, max age 1 minute
 *
 * Data source: public.rpc_get_countries + public.rpc_get_country_currencies
 *   Both RPCs are SECURITY DEFINER, service_role only.
 *
 * rpc_get_country_currencies response shape (one row per country):
 *   { iso_alpha_code, iso_numeric_code, name, default_symbol, native_symbol,
 *     minor_units, status, country_iso2, country_iso3, country_name }
 *
 * The RPC joins catalog.countries → catalog.currencies on default_currency_code
 * where cu.status = 'ACTIVE'.  Each country has exactly one default currency row.
 * supported_currencies in the ERP response is an array of those codes.
 */
export async function GET(request: Request) {
  try {
    const authHeader = request.headers.get("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    const token = authHeader.substring(7);
    const secretStr = process.env.GLOBAL_CONTROL_HMAC_SECRET;
    if (!secretStr) {
      console.error("[S2S] GLOBAL_CONTROL_HMAC_SECRET not configured");
      return NextResponse.json({ error: "Service Unavailable" }, { status: 503 });
    }

    const secretKey = new TextEncoder().encode(secretStr);

    // ── Token verification ───────────────────────────────────────────────────
    let verifiedPayload: Record<string, unknown>;
    try {
      const { payload } = await jwtVerify(token, secretKey, {
        algorithms: ["HS256"],
        issuer: "NAMISH_ERP",
        audience: "NAMISH_GLOBAL_CONTROL",
        maxTokenAge: "1m",
      });
      verifiedPayload = payload as Record<string, unknown>;
    } catch (e) { console.error("JWT ERROR:", e);
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    // exp and iat must both be present (jwtVerify already enforces maxTokenAge
    // but we explicitly reject tokens missing the standard claims).
    if (!verifiedPayload.exp || !verifiedPayload.iat) {
      return NextResponse.json({ error: "Invalid Token Claims" }, { status: 401 });
    }

    if (verifiedPayload.action !== "read_master_data") {
      return NextResponse.json({ error: "Forbidden" }, { status: 403 });
    }

    // ── Data read ────────────────────────────────────────────────────────────
    const admin = createAdminClient();

    const { data: countries, error: countriesErr } =
      await admin.rpc("rpc_get_countries");

    if (countriesErr) {
      console.error("[S2S] rpc_get_countries error:", countriesErr);
      return NextResponse.json(
        { error: "Internal Server Error" },
        { status: 500 }
      );
    }

    // rpc_get_country_currencies returns one row per country (default currency).
    // Response fields: country_iso2, iso_alpha_code  (plus descriptive fields).
    const { data: currencyRows, error: currencyErr } =
      await admin.rpc("rpc_get_country_currencies");

    if (currencyErr) {
      // A failed mapping query must never fall back to an empty/default list.
      console.error("[S2S] rpc_get_country_currencies error:", currencyErr);
      return NextResponse.json(
        { error: "Internal Server Error" },
        { status: 500 }
      );
    }

    // Build iso2 → [iso_alpha_code, …] map.
    // The RPC currently returns one currency per country (default_currency_code).
    // The array form is preserved so ERP's supported_currencies check is stable
    // if the RPC is later extended to return multiple rows per country.
    const supportedMap: Record<string, string[]> = {};
    if (currencyRows) {
      for (const row of currencyRows as Array<{
        country_iso2: string;
        iso_alpha_code: string;
      }>) {
        if (!row.country_iso2 || !row.iso_alpha_code) continue;
        if (!supportedMap[row.country_iso2]) supportedMap[row.country_iso2] = [];
        supportedMap[row.country_iso2].push(row.iso_alpha_code);
      }
    }

    // Merge: attach supported_currencies to each country entry.
    // Country records from rpc_get_countries are keyed by iso2.
    const result = (
      countries as Array<Record<string, unknown>>
    ).map((c) => ({
      ...c,
      supported_currencies: supportedMap[(c.iso2 as string) ?? ""] ?? [],
    }));

    return NextResponse.json(result);
  } catch (err) {
    console.error("[S2S] Unhandled error:", err);
    return NextResponse.json(
      { error: "Internal Server Error" },
      { status: 500 }
    );
  }
}

