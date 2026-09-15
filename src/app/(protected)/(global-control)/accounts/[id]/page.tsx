import { getAuthContext } from '@/utils/auth'
import { createAdminClient } from '@/utils/supabase/admin'
import { redirect } from 'next/navigation'
import Link from 'next/link'
import { ArrowLeft, Building2, ShieldAlert } from 'lucide-react'

type DetailPageProps = {
  params: Promise<{ id: string }>
}

const isValidUUID = (uuid: string | null | undefined) => {
  if (!uuid || typeof uuid !== 'string') return false
  const regex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
  return regex.test(uuid)
}

const isValidDate = (dateStr: string | null | undefined) => {
  if (!dateStr) return false
  const d = new Date(dateStr)
  return !isNaN(d.getTime()) && d.getTime() > 0
}

const formatDate = (dateStr: string | null | undefined) => {
  if (!dateStr) return 'Unknown Date'
  const date = new Date(dateStr)
  if (isNaN(date.getTime()) || date.getTime() <= 0) return 'Unknown Date'
  return date.toLocaleString()
}

export default async function AccountDetailPage({ params }: DetailPageProps) {
  const { staff, error: authError } = await getAuthContext()

  if (authError || !staff || staff.status !== 'ACTIVE') {
    redirect('/login')
  }

  const allowedRoles = ['PLATFORM_SUPERADMIN', 'SUPPORT_AUDITOR']
  if (!allowedRoles.includes(staff.role)) {
    redirect('/')
  }
  
  const isSuperAdmin = staff.role === 'PLATFORM_SUPERADMIN'
  const resolvedParams = await params
  const accountId = resolvedParams.id

  if (!isValidUUID(accountId)) {
    return (
      <div className="space-y-6">
        <Link href="/accounts" className="text-zinc-400 hover:text-white flex items-center gap-2 text-sm transition-colors">
          <ArrowLeft className="w-4 h-4" /> Back to Accounts
        </Link>
        <div className="p-12 text-center bg-zinc-900 border border-zinc-800 rounded-xl">
          <h3 className="text-lg font-medium text-white">Invalid Request</h3>
          <p className="text-zinc-400 mt-1">The provided account identifier is malformed.</p>
        </div>
      </div>
    )
  }

  let adminSupabase: ReturnType<typeof createAdminClient>
  try {
    adminSupabase = createAdminClient()
  } catch (err) {
    return (
      <div className="p-12 text-center bg-zinc-900 border border-zinc-800 rounded-xl">
        <h3 className="text-lg font-medium text-red-400">System Error</h3>
        <p className="text-zinc-400 mt-1">Failed to initialize directory client.</p>
      </div>
    )
  }

  let rawData = null
  let rpcError = null

  try {
    const { data, error } = await adminSupabase.rpc('rpc_get_platform_account_detail', {
      p_account_id: accountId
    })
    rawData = data
    rpcError = error
  } catch (err) {
    rpcError = err
  }
  
  if (rpcError) {
    return (
      <div className="space-y-6">
        <Link href="/accounts" className="text-zinc-400 hover:text-white flex items-center gap-2 text-sm transition-colors">
          <ArrowLeft className="w-4 h-4" /> Back to Accounts
        </Link>
        <div className="p-12 text-center bg-zinc-900 border border-zinc-800 rounded-xl">
          <div className="inline-flex items-center justify-center w-12 h-12 rounded-full bg-red-500/10 mb-4">
            <span className="text-red-400 text-xl">!</span>
          </div>
          <h3 className="text-lg font-medium text-white">Failed to load account</h3>
          <p className="text-zinc-400 mt-1">Error communicating with directory service.</p>
        </div>
      </div>
    )
  }
  
  let result = rawData
  if (typeof rawData === 'string') {
    try {
      result = JSON.parse(rawData)
    } catch (e) {
      // Keep raw
    }
  }

  if (result && result.error === 'ACCOUNT_NOT_FOUND') {
    return (
      <div className="space-y-6">
        <Link href="/accounts" className="text-zinc-400 hover:text-white flex items-center gap-2 text-sm transition-colors">
          <ArrowLeft className="w-4 h-4" /> Back to Accounts
        </Link>
        <div className="p-12 text-center bg-zinc-900 border border-zinc-800 rounded-xl">
          <h3 className="text-lg font-medium text-white">Account Not Found</h3>
          <p className="text-zinc-400 mt-1">The requested account does not exist.</p>
        </div>
      </div>
    )
  }

  if (!result || typeof result !== 'object' || !result.account) {
    return (
      <div className="space-y-6">
        <Link href="/accounts" className="text-zinc-400 hover:text-white flex items-center gap-2 text-sm transition-colors">
          <ArrowLeft className="w-4 h-4" /> Back to Accounts
        </Link>
        <div className="p-12 text-center bg-zinc-900 border border-zinc-800 rounded-xl">
          <h3 className="text-lg font-medium text-white">Invalid Response</h3>
          <p className="text-zinc-400 mt-1">Received a malformed response from the directory service.</p>
        </div>
      </div>
    )
  }

  const { account, erp_bindings, erp_bindings_total } = result
  
  if (!account || typeof account !== 'object' || account.id !== accountId) {
    return (
      <div className="space-y-6">
        <Link href="/accounts" className="text-zinc-400 hover:text-white flex items-center gap-2 text-sm transition-colors">
          <ArrowLeft className="w-4 h-4" /> Back to Accounts
        </Link>
        <div className="p-12 text-center bg-zinc-900 border border-zinc-800 rounded-xl text-red-400">
          Account identity mismatch or malformed response.
        </div>
      </div>
    )
  }
  
  if (typeof account.name !== 'string' && account.name !== null) {
    return <div className="p-12 text-center bg-zinc-900 border border-zinc-800 rounded-xl text-red-400">Malformed account name.</div>
  }
  if (typeof account.status !== 'string' && account.status !== null) {
    return <div className="p-12 text-center bg-zinc-900 border border-zinc-800 rounded-xl text-red-400">Malformed account status.</div>
  }
  if (account.created_at !== null && !isValidDate(account.created_at)) {
    return <div className="p-12 text-center bg-zinc-900 border border-zinc-800 rounded-xl text-red-400">Malformed account created_at.</div>
  }

  if (!Array.isArray(erp_bindings)) {
    return <div className="p-12 text-center bg-zinc-900 border border-zinc-800 rounded-xl text-red-400">Malformed bindings array.</div>
  }
  if (typeof erp_bindings_total !== 'number' || !Number.isSafeInteger(erp_bindings_total) || erp_bindings_total < 0) {
    return <div className="p-12 text-center bg-zinc-900 border border-zinc-800 rounded-xl text-red-400">Malformed bindings total.</div>
  }

  const expectedLen = Math.min(10, erp_bindings_total)
  if (erp_bindings.length !== expectedLen) {
    return <div className="p-12 text-center bg-zinc-900 border border-zinc-800 rounded-xl text-red-400">Binding total inconsistency.</div>
  }

  const allBindingsValid = erp_bindings.every((b: any) => {
    return b && typeof b === 'object' &&
           isValidUUID(b.erp_app_user_id) &&
           (typeof b.provisioned_email === 'string' || b.provisioned_email === null) &&
           (typeof b.provisioned_name === 'string' || b.provisioned_name === null) &&
           (b.created_at === null || isValidDate(b.created_at))
  })
  
  if (!allBindingsValid) {
    return <div className="p-12 text-center bg-zinc-900 border border-zinc-800 rounded-xl text-red-400">Malformed binding details.</div>
  }

  return (
    <div className="space-y-6">
      <Link href="/accounts" className="text-zinc-400 hover:text-white flex items-center gap-2 text-sm transition-colors">
        <ArrowLeft className="w-4 h-4" /> Back to Accounts
      </Link>

      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-white">{account.name || 'Unknown Account'}</h1>
          <p className="text-zinc-400 mt-1 text-sm font-mono">{account.id}</p>
        </div>
        
        {isSuperAdmin && (
          <div className="flex gap-3">
            {account.status !== 'SUSPENDED' && (
              <button disabled className="px-4 py-2 bg-red-500/10 text-red-400 text-sm font-medium rounded-lg border border-red-500/20 opacity-50 cursor-not-allowed" title="Pending execution contract">
                Suspend Account
              </button>
            )}
          </div>
        )}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2 space-y-6">
          <div className="bg-zinc-900 border border-zinc-800 rounded-xl p-6">
            <h2 className="text-lg font-semibold text-white flex items-center gap-2 mb-4">
              <Building2 className="w-5 h-5 text-zinc-400" />
              Recorded ERP Mapping {erp_bindings_total > 0 && `(${erp_bindings_total})`}
            </h2>
            {erp_bindings.length > 0 ? (
              <div className="space-y-4">
                {erp_bindings.map((binding: any, idx: number) => (
                  <div key={idx} className="p-4 bg-zinc-950 border border-zinc-800 rounded-lg">
                    <div className="grid grid-cols-2 gap-4">
                      <div>
                        <p className="text-xs text-zinc-500 uppercase tracking-wider font-semibold">ERP App User ID</p>
                        <p className="text-sm text-zinc-300 font-mono mt-1">{binding.erp_app_user_id}</p>
                      </div>
                      <div>
                        <p className="text-xs text-zinc-500 uppercase tracking-wider font-semibold">Provisioned Email</p>
                        <p className="text-sm text-zinc-300 mt-1">{binding.provisioned_email || 'N/A'}</p>
                      </div>
                      <div className="col-span-2">
                        <p className="text-xs text-zinc-500 uppercase tracking-wider font-semibold">Provisioned Name</p>
                        <p className="text-sm text-zinc-300 mt-1">{binding.provisioned_name || 'N/A'}</p>
                      </div>
                      <div className="col-span-2 border-t border-zinc-800/50 mt-2 pt-2">
                        <p className="text-xs text-zinc-500 uppercase tracking-wider font-semibold">Binding Date</p>
                        <p className="text-sm text-zinc-300 mt-1">{isValidDate(binding.created_at) ? formatDate(binding.created_at) : 'Unknown Date'}</p>
                      </div>
                    </div>
                  </div>
                ))}
                {erp_bindings_total > erp_bindings.length && (
                  <div className="text-sm text-zinc-400 bg-zinc-950 p-4 rounded-lg border border-zinc-800 text-center">
                    + {erp_bindings_total - erp_bindings.length} more bindings truncated
                  </div>
                )}
              </div>
            ) : (
              <div className="text-sm text-zinc-400 bg-zinc-950 p-4 rounded-lg border border-zinc-800">
                No bound ERP mapping recorded.
              </div>
            )}
            <p className="text-xs text-zinc-500 mt-4">
              Provisioned details are snapshots at registration time. Do not treat as verified current ERP profiles.
              Available Enterprise Admins identity depends on actual read contract not yet established.
            </p>
          </div>
        </div>

        <div className="space-y-6">
          <div className="bg-zinc-900 border border-zinc-800 rounded-xl p-6">
            <h2 className="text-sm font-semibold text-white mb-4 uppercase tracking-wider">Account Information</h2>
            <div className="space-y-4">
              <div>
                <p className="text-xs text-zinc-500 font-semibold mb-1">Status</p>
                <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium border ${
                  account.status === 'ACTIVE' ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20' : 
                  'bg-zinc-500/10 text-zinc-400 border-zinc-500/20'
                }`}>
                  {account.status || 'UNKNOWN'}
                </span>
              </div>
              <div>
                <p className="text-xs text-zinc-500 font-semibold mb-1">Registration Date</p>
                <p className="text-sm text-zinc-300">{isValidDate(account.created_at) ? formatDate(account.created_at) : 'Unknown Date'}</p>
              </div>
            </div>
          </div>
          
          <div className="bg-zinc-900 border border-zinc-800 rounded-xl p-6">
            <h2 className="text-sm font-semibold text-white mb-4 uppercase tracking-wider">Commercial Summary</h2>
            <div className="text-sm text-zinc-400">
              <p className="mb-2 flex items-center gap-2"><ShieldAlert className="w-4 h-4 text-amber-400"/> Commercial data unavailable.</p>
              <p className="text-xs">Approved read interfaces for subscription and billing do not yet cover this view.</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
