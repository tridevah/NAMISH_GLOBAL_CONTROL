import { getAuthContext } from '@/utils/auth'
import { createAdminClient } from '@/utils/supabase/admin'
import { redirect } from 'next/navigation'
import Link from 'next/link'
import { Users, CreditCard, Library, Activity, ShieldCheck, Building, ArrowRight } from 'lucide-react'

type MetricResult = { error?: unknown; count: number | null }

const isValidDate = (dateStr: string | null | undefined) => {
  if (!dateStr) return false
  const d = new Date(dateStr)
  return !isNaN(d.getTime()) && d.getTime() > 0
}

const isValidUUID = (uuid: string | null | undefined) => {
  if (!uuid || typeof uuid !== 'string') return false
  const regex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
  return regex.test(uuid)
}

export default async function Dashboard() {
  const { staff, error: authError } = await getAuthContext()

  if (authError || !staff || staff.status !== 'ACTIVE') {
    redirect('/login')
  }

  let adminSupabase: ReturnType<typeof createAdminClient>
  try {
    adminSupabase = createAdminClient()
  } catch (err) {
    return (
      <div className="p-8 text-center text-red-400">Failed to initialize directory client.</div>
    )
  }
  
  const canViewEnterprise = ['PLATFORM_SUPERADMIN', 'SUPPORT_AUDITOR'].includes(staff.role)

  const fetchCount = async (metric: string) => {
    try {
      const { data, error } = await adminSupabase.rpc('rpc_get_dashboard_count', { p_metric_name: metric })
      return { error, count: data }
    } catch (err) {
      return { error: err, count: null }
    }
  }
  
  const fetchEnterpriseList = async () => {
    if (!canViewEnterprise) return { error: new Error('Unauthorized'), data: null }
    try {
      const { data, error } = await adminSupabase.rpc('rpc_list_platform_accounts', { p_page: 1, p_page_size: 5 })
      return { error, data }
    } catch (err) {
      return { error: err, data: null }
    }
  }

  const queries: Promise<any>[] = [
    fetchCount('tenantCount'),
    fetchCount('activeSubs'),
    fetchCount('catalogReleases'),
    fetchCount('pendingOutbox'),
    fetchCount('staffEvents')
  ]
  
  if (canViewEnterprise) {
    queries.push(fetchEnterpriseList())
  }

  const results = await Promise.allSettled(queries)

  const getDisplayValue = (index: number) => {
    const res = results[index]
    if (res.status === 'rejected') return 'Unavailable'
    const data = res.value as MetricResult
    if (data.error || data.count === null || typeof data.count !== 'number') return 'Unavailable'
    if (!Number.isSafeInteger(data.count) || data.count < 0) return 'Unavailable'
    return data.count
  }
  
  const getEnterpriseData = () => {
    if (!canViewEnterprise) return null
    const res = results[5]
    if (res.status === 'rejected') return { error: true, total: null, items: [] }
    const resData = res.value
    if (resData.error || !resData.data) return { error: true, total: null, items: [] }
    
    const total = resData.data.total
    const items = resData.data.items
    
    if (typeof total !== 'number' || !Number.isSafeInteger(total) || total < 0) {
      return { error: true, total: null, items: [] }
    }
    
    if (!Array.isArray(items)) {
      return { error: true, total: null, items: [] }
    }
    
    // Strict mathematically verified count limits
    const expectedLen = Math.min(5, total)
    if (items.length !== expectedLen) {
      return { error: true, total: null, items: [] }
    }

    const isValid = items.every((item: any) => {
      if (!item || typeof item !== 'object') return false
      if (!isValidUUID(item.id)) return false
      if (typeof item.name !== 'string' && item.name !== null) return false
      if (typeof item.status !== 'string' && item.status !== null) return false
      if (item.created_at !== null && !isValidDate(item.created_at)) return false
      return true
    })
    
    if (!isValid) return { error: true, total: null, items: [] }
    
    return { error: false, total, items }
  }

  const enterpriseData = getEnterpriseData()

  const stats = [
    ...(canViewEnterprise ? [{ 
      name: 'Total Enterprise Accounts', 
      value: enterpriseData?.error ? 'Unavailable' : (typeof enterpriseData?.total === 'number' ? enterpriseData.total : 'Unavailable'), 
      icon: Building, 
      color: 'text-purple-400', 
      bg: 'bg-purple-500/10' 
    }] : []),
    { name: 'Total Tenants', value: getDisplayValue(0), icon: Users, color: 'text-blue-400', bg: 'bg-blue-500/10' },
    { name: 'Active Subscriptions', value: getDisplayValue(1), icon: CreditCard, color: 'text-emerald-400', bg: 'bg-emerald-500/10' },
    { name: 'Catalog Releases', value: getDisplayValue(2), icon: Library, color: 'text-indigo-400', bg: 'bg-indigo-500/10' },
    { name: 'Pending Outbox Events', value: getDisplayValue(3), icon: Activity, color: 'text-amber-400', bg: 'bg-amber-500/10' },
    { name: 'Staff Events', value: getDisplayValue(4), icon: ShieldCheck, color: 'text-rose-400', bg: 'bg-rose-500/10' },
  ]
  
  const formatDate = (dateStr: string | null | undefined) => {
    if (!dateStr) return 'Unknown'
    const date = new Date(dateStr)
    if (isNaN(date.getTime()) || date.getTime() <= 0) return 'Unknown'
    return date.toLocaleDateString()
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-white tracking-tight">Platform Dashboard</h1>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {stats.map((stat) => (
          <div key={stat.name} className="bg-zinc-900 border border-zinc-800 rounded-xl p-6 shadow-sm">
            <div className="flex items-center gap-4">
              <div className={`w-12 h-12 rounded-lg flex items-center justify-center ${stat.bg}`}>
                <stat.icon className={`w-6 h-6 ${stat.color}`} />
              </div>
              <div>
                <p className="text-sm font-medium text-zinc-400">{stat.name}</p>
                <p className="text-2xl font-bold text-white mt-1">
                  {typeof stat.value === 'number' ? stat.value.toLocaleString() : stat.value}
                </p>
              </div>
            </div>
          </div>
        ))}
      </div>
      
      {canViewEnterprise && enterpriseData && (
        <div className="bg-zinc-900 border border-zinc-800 rounded-xl p-6 mt-8">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-lg font-semibold text-white">Recent Enterprise Accounts</h2>
            <Link href="/accounts" className="text-sm text-indigo-400 hover:text-indigo-300 flex items-center gap-1 font-medium transition-colors">
              View Directory
              <ArrowRight className="w-4 h-4" />
            </Link>
          </div>
          
          {enterpriseData.error ? (
            <div className="text-sm text-red-400 py-4 bg-red-500/10 rounded-lg px-4 border border-red-500/20">
              Unable to load recent enterprise accounts.
            </div>
          ) : enterpriseData.items.length === 0 ? (
            <div className="text-sm text-zinc-400 py-8 text-center bg-zinc-800/20 rounded-lg border border-zinc-800/50">
              No enterprise accounts registered yet.
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-left border-collapse">
                <thead>
                  <tr className="border-b border-zinc-800">
                    <th className="py-3 px-4 text-xs font-semibold text-zinc-400 uppercase tracking-wider">Account Name</th>
                    <th className="py-3 px-4 text-xs font-semibold text-zinc-400 uppercase tracking-wider">Status</th>
                    <th className="py-3 px-4 text-xs font-semibold text-zinc-400 uppercase tracking-wider">Registered</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-zinc-800/50">
                  {enterpriseData.items.map((account: any) => (
                    <tr key={account.id} className="hover:bg-zinc-800/20 transition-colors">
                      <td className="py-3 px-4">
                        <Link href={`/accounts/${account.id}`} className="text-sm font-medium text-white hover:text-indigo-400 transition-colors">
                          {account.name || 'Unknown'}
                        </Link>
                      </td>
                      <td className="py-3 px-4">
                        <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium border ${
                          account.status === 'ACTIVE' ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20' : 
                          'bg-zinc-500/10 text-zinc-400 border-zinc-500/20'
                        }`}>
                          {account.status || 'UNKNOWN'}
                        </span>
                      </td>
                      <td className="py-3 px-4 text-sm text-zinc-400">
                        {formatDate(account.created_at)}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}

      <div className="bg-zinc-900 border border-zinc-800 rounded-xl p-6 mt-8">
        <h2 className="text-lg font-semibold text-white mb-4">System Status</h2>
        <div className="flex items-center gap-3">
          <div className="w-3 h-3 rounded-full bg-slate-500 shadow-[0_0_8px_rgba(100,116,139,0.5)]"></div>
          <span className="text-sm text-zinc-300">Health status not checked</span>
        </div>
      </div>
    </div>
  )
}
