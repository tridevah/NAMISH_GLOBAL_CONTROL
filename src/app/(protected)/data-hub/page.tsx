import { getAuthContext } from '@/utils/auth'
import { redirect } from 'next/navigation'
import Link from 'next/link'
import { Globe, FileText } from 'lucide-react'
import { createAdminClient } from '@/utils/supabase/admin'

export default async function DataHubDashboard({
  searchParams,
}: {
  searchParams: { country?: string }
}) {
  const { staff } = await getAuthContext()
  if (!staff) redirect('/login')

  const countryId = searchParams.country ?? null
  const querySuffix = countryId ? '?country=' + countryId : ''

  // Determine tax card state from URL country only
  type TaxCardState = 'no_country' | 'not_configured' | 'active'
  let taxCardState: TaxCardState = 'no_country'
  let taxCoverageStatus: string | null = null

  if (countryId) {
    const admin = createAdminClient()
    const { data: coverage } = await admin
      .from('country_tax_coverage')
      .select('status')
      .eq('country_id', countryId)
      .single()

    if (!coverage) {
      // No row in country_tax_coverage → explicitly not configured
      taxCardState = 'not_configured'
    } else if (coverage.status === 'NOT_CONFIGURED') {
      taxCardState = 'not_configured'
    } else {
      // UNRESOLVED, VERIFIED, or any future configured state
      taxCardState = 'active'
      taxCoverageStatus = coverage.status
    }
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight mb-2">ERP Data Hub Dashboard</h1>
        <p className="text-zinc-400 mb-6">Central master data management for ERP integration.</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Geography card — always active */}
        <Link
          href={`/data-hub/geography/countries${querySuffix}`}
          className="block p-6 rounded-xl border border-zinc-800 bg-zinc-900/50 hover:bg-zinc-800/80 transition-colors"
        >
          <div className="flex items-center gap-4">
            <div className="w-12 h-12 bg-blue-500/10 rounded-lg flex items-center justify-center">
              <Globe className="w-6 h-6 text-blue-400" />
            </div>
            <div>
              <h3 className="font-semibold text-lg text-white">Global Geography Master</h3>
              <p className="text-zinc-400 text-sm mt-1">
                Manage supported countries, states, districts, and postal code mappings.
              </p>
            </div>
          </div>
        </Link>

        {/* Tax & Compliance card — 3 states */}
        {taxCardState === 'active' ? (
          <Link
            href={`/data-hub/tax${querySuffix}`}
            className="block p-6 rounded-xl border border-zinc-800 bg-zinc-900/50 hover:bg-zinc-800/80 transition-colors"
          >
            <div className="flex items-center gap-4">
              <div className="w-12 h-12 bg-teal-500/10 rounded-lg flex items-center justify-center">
                <FileText className="w-6 h-6 text-teal-400" />
              </div>
              <div>
                <div className="flex items-center gap-2">
                  <h3 className="font-semibold text-lg text-white">Tax &amp; Compliance</h3>
                  {taxCoverageStatus === 'UNRESOLVED' && (
                    <span className="text-[10px] uppercase font-bold tracking-wider bg-amber-900/50 text-amber-400 px-2 py-0.5 rounded">
                      Verification Pending
                    </span>
                  )}
                </div>
                <p className="text-zinc-400 text-sm mt-1">
                  Country-specific tax regimes, rules, rates, and classification codes.
                </p>
              </div>
            </div>
          </Link>
        ) : (
          <div className="block p-6 rounded-xl border border-dashed border-zinc-800 bg-zinc-900/30 opacity-70 cursor-not-allowed">
            <div className="flex items-center gap-4">
              <div className="w-12 h-12 bg-zinc-800 rounded-lg flex items-center justify-center">
                <FileText className="w-6 h-6 text-zinc-500" />
              </div>
              <div>
                <div className="flex items-center gap-2">
                  <h3 className="font-semibold text-lg text-white">Tax &amp; Compliance</h3>
                  {taxCardState === 'no_country' ? (
                    <span className="text-[10px] uppercase font-bold tracking-wider bg-zinc-700 text-zinc-400 px-2 py-0.5 rounded">
                      Select Country
                    </span>
                  ) : (
                    <span className="text-[10px] uppercase font-bold tracking-wider bg-zinc-700 text-zinc-400 px-2 py-0.5 rounded">
                      Not Configured
                    </span>
                  )}
                </div>
                <p className="text-zinc-500 text-sm mt-1">
                  {taxCardState === 'no_country'
                    ? 'Select a country to view tax master data.'
                    : 'Tax configuration is not yet available for this country.'}
                </p>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
