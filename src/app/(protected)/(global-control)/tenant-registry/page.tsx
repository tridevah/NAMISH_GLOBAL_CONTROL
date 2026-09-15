import { getAuthContext } from '@/utils/auth'
import { createAdminClient } from '@/utils/supabase/admin'
import { redirect } from 'next/navigation'
import { Building2, AlertCircle, ChevronLeft, ChevronRight } from 'lucide-react'
import Link from 'next/link'

export const dynamic = 'force-dynamic'

// ── Types ────────────────────────────────────────────────────────────────────

type TenantRow = {
  id: string
  platform_account_id: string | null
  erp_tenant_id: string | null
  status: string
  created_at: string | null
}

type RpcListTenantsResult = {
  items: TenantRow[]
  total: number
  page: number
  page_size: number
}

// ── Constants and response validation ─────────────────────────────────────────

const ALLOWED_ROLES = ['PLATFORM_SUPERADMIN', 'SUPPORT_AUDITOR'] as const
const DEFAULT_PAGE_SIZE = 50
const MAX_PAGE = 2147483647

function parsePage(rawPage: string | string[] | undefined): number {
  if (typeof rawPage !== 'string' || !/^\d+$/.test(rawPage)) return 1
  const parsed = Number(rawPage)
  return Number.isSafeInteger(parsed) && parsed >= 1 && parsed <= MAX_PAGE ? parsed : 1
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value)
}

function isSafeIntegerInRange(value: unknown, min: number, max: number): value is number {
  return typeof value === 'number' && Number.isSafeInteger(value) && value >= min && value <= max
}

function isNullableString(value: unknown): value is string | null {
  return value === null || typeof value === 'string'
}

function isTimestamp(value: unknown): value is string | null {
  return value === null || (
    typeof value === 'string' &&
    /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})?$/.test(value) &&
    Number.isFinite(Date.parse(value))
  )
}

function isTenantRow(value: unknown): value is TenantRow {
  return isRecord(value) &&
    typeof value.id === 'string' && value.id.length > 0 &&
    isNullableString(value.platform_account_id) &&
    isNullableString(value.erp_tenant_id) &&
    typeof value.status === 'string' &&
    isTimestamp(value.created_at)
}

function isListResult(value: unknown, requestedPage: number): value is RpcListTenantsResult {
  if (!isRecord(value) || !Array.isArray(value.items) ||
      !isSafeIntegerInRange(value.total, 0, Number.MAX_SAFE_INTEGER) ||
      !isSafeIntegerInRange(value.page, 1, MAX_PAGE) ||
      !isSafeIntegerInRange(value.page_size, 1, 100) ||
      value.page !== requestedPage || value.page_size !== DEFAULT_PAGE_SIZE ||
      !value.items.every(isTenantRow)) return false

  const offset = (value.page - 1) * value.page_size
  const expectedLength = Math.min(value.page_size, Math.max(0, value.total - offset))
  return value.items.length === expectedLength
}

const STATUS_VARIANTS = new Map<string, string>([
  ['ACTIVE', 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20'],
  ['PROVISIONING', 'bg-amber-500/10 text-amber-400 border-amber-500/20'],
  ['FAILED', 'bg-red-500/10 text-red-400 border-red-500/20'],
  ['SUSPENDED', 'bg-zinc-700 text-zinc-300 border-zinc-600'],
])

function statusClass(status: string): string {
  return STATUS_VARIANTS.get(status) ?? 'bg-zinc-800 text-zinc-400 border-zinc-700'
}

function displayDate(value: string | null): string {
  return value === null ? '—' : new Date(value).toLocaleDateString('en-IN', {
    day: '2-digit', month: 'short', year: 'numeric', timeZone: 'UTC',
  })
}

// ── Status badge ──────────────────────────────────────────────────────────────

function StatusBadge({ status }: { status: string }) {
  return (
    <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium border ${statusClass(status)}`}>
      {status}
    </span>
  )
}

// ── Page ──────────────────────────────────────────────────────────────────────

export default async function TenantRegistryPage(props: {
  searchParams: Promise<{ page?: string | string[] }>
}) {
  // 1. Auth: validate session and ACTIVE staff status
  const { staff, error: authError } = await getAuthContext()

  if (authError || !staff || staff.status !== 'ACTIVE') {
    redirect('/login')
  }

  // 2. Role gate: only PLATFORM_SUPERADMIN and SUPPORT_AUDITOR
  if (typeof staff.role !== 'string' || !(ALLOWED_ROLES as readonly string[]).includes(staff.role)) {
    redirect('/')
  }

  // 3. Validate query parameters before constructing the RPC request.
  const rawSearchParams = await props.searchParams
  const page = parsePage(rawSearchParams.page)

  // 4. Keep RPC failures and malformed payloads in the page's error state.
  let result: RpcListTenantsResult | null = null
  let parseError: 'query_failed' | 'malformed_response' | null = null
  try {
    const adminSupabase = createAdminClient()
    const { data: rpcData, error: rpcError } = await adminSupabase.rpc(
      'rpc_list_tenants',
      { p_page: page, p_page_size: DEFAULT_PAGE_SIZE }
    )
    if (rpcError) {
      console.error('[TenantRegistry] Tenant list query failed')
      parseError = 'query_failed'
    } else if (!isListResult(rpcData, page)) {
      console.error('[TenantRegistry] Invalid tenant list response')
      parseError = 'malformed_response'
    } else {
      result = rpcData
    }
  } catch {
    // Do not log response payloads, transport headers, credentials or tenant rows.
    console.error('[TenantRegistry] Tenant list request failed')
    parseError = 'query_failed'
  }

  // 5. Only validated response metadata drives rendering and pagination.
  const totalItems = result?.total ?? 0
  const serverPageSize = result?.page_size ?? DEFAULT_PAGE_SIZE
  const serverPage = result?.page ?? 1
  const totalPages = Math.max(1, Math.ceil(totalItems / serverPageSize))
  const isOutOfRange = result !== null && totalItems > 0 && serverPage > totalPages
  const isEmptyRegistry = result !== null && totalItems === 0

  // ── Render ──────────────────────────────────────────────────────────────────

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold tracking-tight text-white">Tenant Registry</h1>
        <p className="text-zinc-400 mt-1 text-sm">
          Platform tenants.
          {result && (
            <span className="ml-2 text-zinc-500">({totalItems.toLocaleString()} total)</span>
          )}
        </p>
      </div>

      {/* Error state — user-facing message only; diagnostic details logged server-side */}
      {parseError && (
        <div className="flex items-start gap-3 p-4 bg-red-900/20 border border-red-800/50 rounded-xl text-red-300">
          <AlertCircle className="w-5 h-5 mt-0.5 shrink-0 text-red-400" />
          <div>
            <p className="text-sm font-medium">Unable to load tenant data</p>
            <p className="text-xs text-red-400 mt-0.5">
              Please try again or contact support.
            </p>
          </div>
        </div>
      )}

      {/* Table — only rendered when no error */}
      {!parseError && result && (
        <>
          <div className="border border-zinc-800 rounded-xl overflow-hidden bg-zinc-900/30">
            <table className="w-full text-left text-sm">
              <thead className="bg-zinc-900/80 border-b border-zinc-800 text-zinc-400">
                <tr>
                  <th className="px-6 py-3 font-medium">Tenant ID</th>
                  <th className="px-6 py-3 font-medium">Account ID</th>
                  <th className="px-6 py-3 font-medium">ERP Tenant ID</th>
                  <th className="px-6 py-3 font-medium">Status</th>
                  <th className="px-6 py-3 font-medium">Created</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-zinc-800/50">
                {/* Out of range vs Empty registry */}
                {isOutOfRange ? (
                  <tr>
                    <td colSpan={5} className="px-6 py-12 text-center text-zinc-500">
                      <AlertCircle className="w-8 h-8 mx-auto mb-3 text-zinc-700" />
                      <p>Page {serverPage} is out of range.</p>
                      <Link href="/tenant-registry?page=1" className="inline-block mt-3 text-indigo-400 hover:text-indigo-300">
                        Go to first page
                      </Link>
                    </td>
                  </tr>
                ) : isEmptyRegistry ? (
                  <tr>
                    <td colSpan={5} className="px-6 py-12 text-center text-zinc-500">
                      <Building2 className="w-8 h-8 mx-auto mb-3 text-zinc-700" />
                      No tenants registered.
                    </td>
                  </tr>
                ) : (
                  result.items.map(t => (
                    <tr key={t.id} className="hover:bg-zinc-800/30 transition-colors">
                      <td className="px-6 py-3 font-mono text-xs text-zinc-300 max-w-[140px] truncate" title={t.id}>
                        {t.id}
                      </td>
                      <td className="px-6 py-3 font-mono text-xs text-zinc-400 max-w-[140px] truncate" title={t.platform_account_id ?? ''}>
                        {t.platform_account_id ?? <span className="text-zinc-600">—</span>}
                      </td>
                      <td className="px-6 py-3 font-mono text-xs text-zinc-400 max-w-[140px] truncate" title={t.erp_tenant_id ?? ''}>
                        {t.erp_tenant_id ?? <span className="text-zinc-600">—</span>}
                      </td>
                      <td className="px-6 py-3">
                        <StatusBadge status={t.status} />
                      </td>
                      <td className="px-6 py-3 text-zinc-400 text-xs">
                        {displayDate(t.created_at)}
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>

          {/* Pagination — only shown when total > page_size */}
          {totalItems > serverPageSize && (
            <div className="flex items-center justify-between text-sm text-zinc-400">
              <span>
                Page {serverPage} of {totalPages}
              </span>
              <div className="flex items-center gap-2">
                {serverPage > 1 ? (
                  <Link
                    href={`/tenant-registry?page=${serverPage - 1}`}
                    className="flex items-center gap-1 px-3 py-1.5 rounded-lg bg-zinc-800 hover:bg-zinc-700 text-zinc-300 transition-colors"
                  >
                    <ChevronLeft className="w-4 h-4" />
                    Previous
                  </Link>
                ) : (
                  <span className="flex items-center gap-1 px-3 py-1.5 rounded-lg bg-zinc-900 text-zinc-600 cursor-not-allowed">
                    <ChevronLeft className="w-4 h-4" />
                    Previous
                  </span>
                )}
                {serverPage < totalPages ? (
                  <Link
                    href={`/tenant-registry?page=${serverPage + 1}`}
                    className="flex items-center gap-1 px-3 py-1.5 rounded-lg bg-zinc-800 hover:bg-zinc-700 text-zinc-300 transition-colors"
                  >
                    Next
                    <ChevronRight className="w-4 h-4" />
                  </Link>
                ) : (
                  <span className="flex items-center gap-1 px-3 py-1.5 rounded-lg bg-zinc-900 text-zinc-600 cursor-not-allowed">
                    Next
                    <ChevronRight className="w-4 h-4" />
                  </span>
                )}
              </div>
            </div>
          )}
        </>
      )}
    </div>
  )
}
