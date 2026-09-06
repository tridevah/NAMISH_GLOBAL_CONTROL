import { getAuthContext } from '@/utils/auth'
import { redirect } from 'next/navigation'
import Link from 'next/link'
import { Globe, Map, FileText, AlertTriangle } from 'lucide-react'
import { createClient } from '@/utils/supabase/server'

export default async function DataHubDashboard({ searchParams }: { searchParams: { country?: string } }) {
  const { staff } = await getAuthContext()
  if (!staff) redirect('/login')

  let taxActive = false
  if (searchParams.country) {
    const supabase = createClient()
    const { data: country } = await supabase
      .from('countries')
      .select('tax_coverage')
      .eq('id', searchParams.country)
      .single()
    
    if (country && country.tax_coverage !== 'NOT_CONFIGURED') {
      taxActive = true
    }
  }

  const querySuffix = searchParams.country ? '?country=' + searchParams.country : ''

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight mb-2">ERP Data Hub Dashboard</h1>
        <p className="text-zinc-400 mb-6">Central master data management for ERP integration.</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <Link href={`/data-hub/geography/countries${querySuffix}`} className="block p-6 rounded-xl border border-zinc-800 bg-zinc-900/50 hover:bg-zinc-800/80 transition-colors">
          <div className="flex items-center gap-4">
            <div className="w-12 h-12 bg-blue-500/10 rounded-lg flex items-center justify-center">
              <Globe className="w-6 h-6 text-blue-400" />
            </div>
            <div>
              <h3 className="font-semibold text-lg text-white">Global Geography Master</h3>
              <p className="text-zinc-400 text-sm mt-1">Manage supported countries, states, districts, and postal code mappings.</p>
            </div>
          </div>
        </Link>
        
        {taxActive ? (
          <Link href={`/data-hub/tax${querySuffix}`} className="block p-6 rounded-xl border border-zinc-800 bg-zinc-900/50 hover:bg-zinc-800/80 transition-colors">
            <div className="flex items-center gap-4">
              <div className="w-12 h-12 bg-teal-500/10 rounded-lg flex items-center justify-center">
                <FileText className="w-6 h-6 text-teal-400" />
              </div>
              <div>
                <h3 className="font-semibold text-lg text-white">Tax & Compliance</h3>
                <p className="text-zinc-400 text-sm mt-1">Country-specific tax regimes, rules, rates, and classification codes.</p>
              </div>
            </div>
          </Link>
        ) : (
          <div className="block p-6 rounded-xl border border-dashed border-zinc-800 bg-zinc-900/30 opacity-70">
            <div className="flex items-center gap-4">
              <div className="w-12 h-12 bg-zinc-800 rounded-lg flex items-center justify-center">
                <FileText className="w-6 h-6 text-zinc-500" />
              </div>
              <div>
                <div className="flex items-center gap-2">
                  <h3 className="font-semibold text-lg text-white">Tax & Compliance</h3>
                  <span className="text-[10px] uppercase font-bold tracking-wider bg-teal-900/50 text-teal-400 px-2 py-0.5 rounded">Coming Soon</span>
                </div>
                <p className="text-zinc-500 text-sm mt-1">Country-specific tax regimes, rules, rates, and classification codes.</p>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}

