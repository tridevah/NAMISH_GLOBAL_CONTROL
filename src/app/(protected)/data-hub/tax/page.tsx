import { getAuthContext } from '@/utils/auth'
import { redirect } from 'next/navigation'
import { CheckCircle2, Database, AlertCircle } from 'lucide-react'
import Link from 'next/link'
import { createAdminClient } from '@/utils/supabase/admin'
import { createClient } from '@/utils/supabase/server'

export default async function TaxOverviewPage(props: { searchParams: Promise<{ country?: string }> }) {
  const { staff } = await getAuthContext()
  if (!staff) redirect('/login')

  const searchParams = await props.searchParams
  const activeCountryId = searchParams.country

  const userSupabase = await createClient()
  const admin = createAdminClient()

  // 1. Fetch country info
  let country: any = null
  if (activeCountryId) {
    const { data } = await userSupabase
      .from('countries')
      .select('id, iso2, display_name')
      .eq('id', activeCountryId)
      .single()
    country = data
  }

  // Only proceed with stats if country is IN
  let isConfigured = false
  let stats = {
    gstRates: 0,
    hsnCodes: 0,
    sacCodes: 0,
    authorities: 0
  }

  if (country?.iso2 === 'IN') {
    isConfigured = true
    
    const [
      { count: gstRatesCount },
      { count: hsnCount },
      { count: sacCount },
      { count: authCount }
    ] = await Promise.all([
      admin.from('gst_rate_master').select('*', { count: 'exact', head: true }).eq('country_id', activeCountryId),
      admin.from('hsn_sac').select('*', { count: 'exact', head: true }).eq('country_id', activeCountryId).eq('code_type', 'HSN'),
      admin.from('hsn_sac').select('*', { count: 'exact', head: true }).eq('country_id', activeCountryId).eq('code_type', 'SAC'),
      admin.from('tax_authorities').select('*', { count: 'exact', head: true }).eq('country_id', activeCountryId)
    ])

    stats = {
      gstRates: gstRatesCount ?? 0,
      hsnCodes: hsnCount ?? 0,
      sacCodes: sacCount ?? 0,
      authorities: authCount ?? 0
    }
  }

  const querySuffix = activeCountryId ? `?country=${activeCountryId}` : ''

  return (
    <div className="p-6 md:p-8 max-w-5xl space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight mb-1 text-white flex items-center gap-2">
          <Database className="w-6 h-6 text-teal-500" />
          Tax Master Data
        </h1>
        <p className="text-zinc-400">
          {country ? `Showing master data configuration for ${country.display_name} (${country.iso2})` : 'Select a country to view configuration.'}
        </p>
      </div>

      {!country ? (
        <div className="p-8 border border-zinc-800 rounded-xl bg-zinc-900/30 text-zinc-400 text-center">
          Please select a country from the sidebar dropdown.
        </div>
      ) : isConfigured ? (
        <>
          <div className="bg-teal-500/10 border border-teal-500/20 p-4 rounded-xl flex items-start gap-3">
            <CheckCircle2 className="w-5 h-5 text-teal-400 shrink-0 mt-0.5" />
            <div>
              <div className="text-teal-400 font-medium text-sm">MASTER DATA LOADED — PENDING ERP VERIFICATION</div>
              <div className="text-teal-400/80 text-xs mt-1">GST Rate Master (12 rates), HSN Directory ({stats.hsnCodes.toLocaleString()} codes) and SAC Directory ({stats.sacCodes.toLocaleString()} codes) are loaded from official sources. <strong className="text-orange-400 block mt-1">DO NOT EXPOSE to NAMISH_ERP until rate content is verified against latest official notification.</strong></div>
            </div>
          </div>

          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            <div className="bg-zinc-900 border border-zinc-800 rounded-xl p-5">
              <div className="text-zinc-400 text-sm mb-1">GST Rates</div>
              <div className="text-3xl font-bold text-white">{stats.gstRates}</div>
              <div className="text-xs text-zinc-500 mt-1">12 total · 11 current</div>
            </div>
            <div className="bg-zinc-900 border border-zinc-800 rounded-xl p-5">
              <div className="text-zinc-400 text-sm mb-1">HSN Codes</div>
              <div className="text-3xl font-bold text-white">{stats.hsnCodes.toLocaleString()}</div>
              <div className="text-xs text-zinc-500 mt-1">ITC(HS) 2022 + DGFT Notif 24/2026-27</div>
            </div>
            <div className="bg-zinc-900 border border-zinc-800 rounded-xl p-5">
              <div className="text-zinc-400 text-sm mb-1">SAC Codes</div>
              <div className="text-3xl font-bold text-white">{stats.sacCodes.toLocaleString()}</div>
              <div className="text-xs text-zinc-500 mt-1">Annexure 11/2017 · Amended 12/2023</div>
            </div>
            <div className="bg-zinc-900 border border-zinc-800 rounded-xl p-5">
              <div className="text-zinc-400 text-sm mb-1">Tax Authorities</div>
              <div className="text-3xl font-bold text-white">{stats.authorities}</div>
            </div>
          </div>

          <div className="flex gap-3 flex-wrap pt-2">
            <Link href={`/data-hub/tax/gst-rates${querySuffix}`} className="px-4 py-2 bg-teal-600/20 text-teal-400 border border-teal-600/30 text-sm font-medium rounded-lg hover:bg-teal-600/30 transition-colors">
              GST Rates →
            </Link>
            <Link href={`/data-hub/tax/hsn-sac${querySuffix}`} className="px-4 py-2 bg-teal-600/20 text-teal-400 border border-teal-600/30 text-sm font-medium rounded-lg hover:bg-teal-600/30 transition-colors">
              HSN/SAC Codes →
            </Link>
            <Link href={`/data-hub/tax/authorities${querySuffix}`} className="px-4 py-2 bg-zinc-800 text-zinc-300 border border-zinc-700 text-sm font-medium rounded-lg hover:bg-zinc-700 transition-colors">
              Tax Authorities →
            </Link>
          </div>
        </>
      ) : (
        <div className="bg-orange-500/10 border border-orange-500/20 p-6 rounded-xl flex items-start gap-3">
          <AlertCircle className="w-5 h-5 text-orange-400 shrink-0 mt-0.5" />
          <div>
            <div className="text-orange-400 font-medium text-sm">Tax system not configured for this country.</div>
            <div className="text-orange-400/80 text-xs mt-1">India (IN) is currently the only country with an active GST configuration. Select India from the country dropdown to view the configured tax framework.</div>
          </div>
        </div>
      )}
    </div>
  )
}
