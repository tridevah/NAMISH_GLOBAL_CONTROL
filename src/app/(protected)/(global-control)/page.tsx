import { createClient } from '@/utils/supabase/server'
import { Users, CreditCard, Library, Activity, ShieldCheck, Mail, AlertTriangle } from 'lucide-react'

export default async function Dashboard() {
  const supabase = await createClient()

  // Execute in parallel
  const [
    { count: tenantCount }, 
    { count: activeSubs }, 
    { count: catalogReleases }, 
    { count: pendingOutbox }, 
    { count: staffEvents }
  ] = await Promise.all([
    supabase.schema('platform').from('tenant_registry').select('*', { count: 'exact', head: true }),
    supabase.schema('billing').from('subscriptions').select('*', { count: 'exact', head: true }).eq('status', 'ACTIVE'),
    supabase.schema('catalog').from('catalog_releases').select('*', { count: 'exact', head: true }),
    supabase.schema('integration').from('outbox_events').select('*', { count: 'exact', head: true }).eq('status', 'PENDING'),
    supabase.schema('audit').from('staff_events').select('*', { count: 'exact', head: true })
  ])

  const stats = [
    { name: 'Total Tenants', value: tenantCount || 0, icon: Users, color: 'text-blue-400', bg: 'bg-blue-500/10' },
    { name: 'Active Subscriptions', value: activeSubs || 0, icon: CreditCard, color: 'text-emerald-400', bg: 'bg-emerald-500/10' },
    { name: 'Catalog Releases', value: catalogReleases || 0, icon: Library, color: 'text-indigo-400', bg: 'bg-indigo-500/10' },
    { name: 'Pending Outbox Events', value: pendingOutbox || 0, icon: Activity, color: 'text-amber-400', bg: 'bg-amber-500/10' },
    { name: 'Recent Staff Events', value: staffEvents || 0, icon: ShieldCheck, color: 'text-rose-400', bg: 'bg-rose-500/10' },
  ]

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
                <p className="text-2xl font-bold text-white mt-1">{stat.value.toLocaleString()}</p>
              </div>
            </div>
          </div>
        ))}
      </div>

      <div className="bg-zinc-900 border border-zinc-800 rounded-xl p-6 mt-8">
        <h2 className="text-lg font-semibold text-white mb-4">System Status</h2>
        <div className="flex items-center gap-3">
          <div className="w-3 h-3 rounded-full bg-emerald-500 shadow-[0_0_8px_rgba(16,185,129,0.5)]"></div>
          <span className="text-sm text-zinc-300">All systems operational</span>
        </div>
      </div>
    </div>
  )
}
