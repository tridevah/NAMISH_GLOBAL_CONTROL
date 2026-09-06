'use client'

import { useState, useMemo } from 'react'
import { Percent, AlertCircle, ExternalLink, Search, Info } from 'lucide-react'

const CATEGORY_BADGE: Record<string, string> = {
    STANDARD:    'bg-teal-500/10 text-teal-400',
    NIL:         'bg-zinc-700 text-zinc-300',
    SPECIAL:     'bg-yellow-500/10 text-yellow-400',
    COMPOSITION: 'bg-blue-500/10 text-blue-400',
    HISTORICAL:  'bg-red-500/10 text-red-400',
    EXEMPT:      'bg-purple-500/10 text-purple-400',
}

const ERP_VIS_BADGE: Record<string, string> = {
    GENERAL:         'bg-green-500/10 text-green-400',
    CONTEXT_ONLY:    'bg-amber-500/10 text-amber-400',
    NEVER_LINE_ITEM: 'bg-blue-500/10 text-blue-400',
    HIDDEN:          'bg-zinc-700 text-zinc-500',
}

const SCOPE_LABELS: Record<string, string> = {
    TRANSACTION_RATE: 'Transaction',
    TAXPAYER_SCHEME:  'Composition Scheme',
    HISTORICAL:       'Historical',
}

type GstRate = {
    id: string
    rate_percent: string
    rate_name: string
    category: string
    is_current: boolean
    status: string
    notification_number: string
    notification_date: string
    official_source?: string
    notes?: string
    effective_from?: string
    effective_to?: string
    rate_code: string
    usage_scope: string
    erp_visibility: string
    statutory_rate_percent: string
    effective_display_percent: string
    valuation_basis?: string
    itc_policy?: string
    conditions?: Record<string, unknown>
}

export default function GstRatesClient({ rates, dbError }: { rates: GstRate[], dbError?: string }) {
    const [search, setSearch] = useState('')
    const [scopeFilter, setScopeFilter] = useState<'ALL' | 'TRANSACTION_RATE' | 'TAXPAYER_SCHEME' | 'HISTORICAL'>('TRANSACTION_RATE')

    const filtered = useMemo(() => {
        return rates.filter(r => {
            if (scopeFilter !== 'ALL' && r.usage_scope !== scopeFilter) return false
            if (search) {
                const q = search.toLowerCase()
                return r.rate_name.toLowerCase().includes(q)
                    || String(r.rate_percent).includes(q)
                    || (r.notification_number || '').toLowerCase().includes(q)
                    || (r.notes || '').toLowerCase().includes(q)
                    || (r.rate_code || '').toLowerCase().includes(q)
            }
            return true
        })
    }, [rates, search, scopeFilter])

    const transactionRates = filtered.filter(r => r.usage_scope === 'TRANSACTION_RATE')
    const compositionRates = filtered.filter(r => r.usage_scope === 'TAXPAYER_SCHEME')
    const historicalRates  = filtered.filter(r => r.usage_scope === 'HISTORICAL')

    return (
        <div className="space-y-6">
            {/* Header */}
            <div>
                <h1 className="text-2xl font-bold text-white flex items-center gap-2 mb-1">
                    <Percent className="w-6 h-6 text-teal-400" />
                    GST Rate Master
                </h1>
                <p className="text-zinc-400 text-sm">
                    Official GST rate schedules as notified under CGST Act 2017 and amendments.
                    This is a standalone master list — no product or HSN/SAC assignment is made here.
                </p>
            </div>

            {dbError && (
                <div className="p-4 border border-red-500/30 bg-red-500/10 rounded-lg flex items-center gap-3 text-red-400 text-sm">
                    <AlertCircle className="w-5 h-5 shrink-0" />
                    Database error: {dbError}
                </div>
            )}

            {/* Filters */}
            <div className="flex flex-wrap gap-3 items-center">
                <div className="relative flex-1 min-w-48">
                    <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-500" />
                    <input
                        type="text"
                        placeholder="Search rate name, code, notification…"
                        value={search}
                        onChange={e => setSearch(e.target.value)}
                        className="w-full pl-9 pr-4 py-2 bg-zinc-900 border border-zinc-800 rounded-lg text-sm text-white placeholder:text-zinc-600 focus:outline-none focus:border-teal-600"
                    />
                </div>

                <div className="flex gap-1">
                    {(['ALL', 'TRANSACTION_RATE', 'TAXPAYER_SCHEME', 'HISTORICAL'] as const).map(s => (
                        <button
                            key={s}
                            onClick={() => setScopeFilter(s)}
                            className={`px-3 py-2 rounded-lg text-xs font-medium transition-colors ${scopeFilter === s ? 'bg-teal-600 text-white' : 'bg-zinc-900 border border-zinc-800 text-zinc-400 hover:text-white'}`}
                        >
                            {s === 'ALL' ? 'All' : SCOPE_LABELS[s]}
                        </button>
                    ))}
                </div>

                <span className="text-zinc-500 text-sm ml-auto">{filtered.length} of {rates.length} rates</span>
            </div>

            <div className="space-y-8">
                {/* Transaction Rates Table */}
                {transactionRates.length > 0 && (
                    <div className="bg-zinc-900 border border-zinc-800 rounded-xl overflow-hidden">
                        <h3 className="px-4 py-3 bg-zinc-800/80 text-white font-medium border-b border-zinc-700">
                            Transaction Rates
                        </h3>
                        <div className="overflow-x-auto">
                            <table className="w-full text-sm text-left">
                                <thead className="bg-zinc-800/50 text-zinc-400 text-xs uppercase tracking-wide border-b border-zinc-800">
                                    <tr>
                                        <th className="px-4 py-3 w-20">Stat. %</th>
                                        <th className="px-4 py-3 w-20">Eff. %</th>
                                        <th className="px-4 py-3">Rate Name</th>
                                        <th className="px-4 py-3 w-24">Category</th>
                                        <th className="px-4 py-3 w-28">ERP Visibility</th>
                                        <th className="px-4 py-3 w-20">Status</th>
                                        <th className="px-4 py-3">Notification</th>
                                        <th className="px-4 py-3 w-24">Eff. From</th>
                                        <th className="px-4 py-3 w-16">Source</th>
                                    </tr>
                                </thead>
                                <tbody className="divide-y divide-zinc-800">
                                    {transactionRates.map(r => (
                                        <tr key={r.id} className={`hover:bg-zinc-800/30 ${!r.is_current ? 'opacity-60' : ''}`}>
                                            <td className="px-4 py-3 font-mono font-bold text-white text-base">{r.statutory_rate_percent ?? r.rate_percent}%</td>
                                            <td className="px-4 py-3 font-mono text-zinc-300">{r.effective_display_percent ?? r.rate_percent}%</td>
                                            <td className="px-4 py-3 text-zinc-200 font-medium">
                                                {r.rate_name}
                                                {r.erp_visibility === 'CONTEXT_ONLY' && (
                                                    <span className="ml-2 text-xs text-amber-500/80" title={r.notes || 'Context-only rate'}>
                                                        <Info className="inline w-3 h-3" />
                                                    </span>
                                                )}
                                            </td>
                                            <td className="px-4 py-3">
                                                <span className={`px-2 py-0.5 rounded text-xs font-mono ${CATEGORY_BADGE[r.category] ?? 'bg-zinc-700 text-zinc-400'}`}>
                                                    {r.category}
                                                </span>
                                            </td>
                                            <td className="px-4 py-3">
                                                <span className={`px-2 py-0.5 rounded text-xs font-mono ${ERP_VIS_BADGE[r.erp_visibility] ?? 'bg-zinc-700 text-zinc-400'}`}>
                                                    {r.erp_visibility}
                                                </span>
                                            </td>
                                            <td className="px-4 py-3">
                                                <span className={`px-2 py-0.5 rounded-full text-xs ${r.status === 'ACTIVE' ? 'bg-green-500/10 text-green-400' : 'bg-zinc-700 text-zinc-500'}`}>
                                                    {r.status}
                                                </span>
                                            </td>
                                            <td className="px-4 py-3 text-zinc-400 text-xs font-mono">{r.notification_number || '—'}</td>
                                            <td className="px-4 py-3 text-zinc-400 text-xs">{r.effective_from || '—'}</td>
                                            <td className="px-4 py-3">
                                                {r.official_source ? (
                                                    <a href={r.official_source} target="_blank" rel="noopener noreferrer" className="text-blue-400 hover:text-blue-300">
                                                        <ExternalLink className="w-3.5 h-3.5" />
                                                    </a>
                                                ) : <span className="text-zinc-700">—</span>}
                                            </td>
                                        </tr>
                                    ))}
                                </tbody>
                            </table>
                        </div>
                        {/* Context-only footnotes */}
                        <div className="px-4 py-3 border-t border-zinc-800 space-y-1">
                            <p className="text-zinc-500 text-xs flex items-center gap-1">
                                <Info className="w-3 h-3 text-amber-500/70 shrink-0" />
                                <span><strong className="text-amber-500/80">CONTEXT_ONLY</strong> rates have usage restrictions. &quot;Merchant-export procurement only&quot; applies only to supplies to merchant-exporters (0.05% CGST + 0.05% SGST/UTGST). &quot;Specified bricks/tiles only&quot; applies under Notification 14/2025-CT(R) scope. Real-estate rates use 2/3 valuation — not applicable to generic item lines.</span>
                            </p>
                        </div>
                    </div>
                )}

                {/* Composition Schemes Table */}
                {compositionRates.length > 0 && (
                    <div className="bg-zinc-900 border border-zinc-800 rounded-xl overflow-hidden">
                        <h3 className="px-4 py-3 bg-zinc-800/80 text-white font-medium border-b border-zinc-700">
                            Composition Schemes
                            <span className="ml-2 text-xs text-blue-400 font-normal">Taxpayer-level scheme — never applied at invoice line level</span>
                        </h3>
                        <div className="overflow-x-auto">
                            <table className="w-full text-sm text-left">
                                <thead className="bg-zinc-800/50 text-zinc-400 text-xs uppercase tracking-wide border-b border-zinc-800">
                                    <tr>
                                        <th className="px-4 py-3 w-20">Rate %</th>
                                        <th className="px-4 py-3">Scheme Name</th>
                                        <th className="px-4 py-3 w-28">Valuation</th>
                                        <th className="px-4 py-3 w-20">ITC</th>
                                        <th className="px-4 py-3 w-20">Status</th>
                                        <th className="px-4 py-3">Notification</th>
                                        <th className="px-4 py-3 w-24">Eff. From</th>
                                        <th className="px-4 py-3 w-16">Source</th>
                                    </tr>
                                </thead>
                                <tbody className="divide-y divide-zinc-800">
                                    {compositionRates.map(r => (
                                        <tr key={r.id} className="hover:bg-zinc-800/30">
                                            <td className="px-4 py-3 font-mono font-bold text-white text-base">{r.rate_percent}%</td>
                                            <td className="px-4 py-3 text-zinc-200 font-medium">{r.rate_name}</td>
                                            <td className="px-4 py-3 text-zinc-400 text-xs font-mono">{r.valuation_basis || 'TURNOVER'}</td>
                                            <td className="px-4 py-3">
                                                <span className={`px-2 py-0.5 rounded text-xs ${r.itc_policy === 'NO_ITC' ? 'bg-red-500/10 text-red-400' : 'bg-green-500/10 text-green-400'}`}>
                                                    {r.itc_policy || 'NO_ITC'}
                                                </span>
                                            </td>
                                            <td className="px-4 py-3">
                                                <span className={`px-2 py-0.5 rounded-full text-xs ${r.status === 'ACTIVE' ? 'bg-green-500/10 text-green-400' : 'bg-zinc-700 text-zinc-500'}`}>
                                                    {r.status}
                                                </span>
                                            </td>
                                            <td className="px-4 py-3 text-zinc-400 text-xs font-mono">{r.notification_number || '—'}</td>
                                            <td className="px-4 py-3 text-zinc-400 text-xs">{r.effective_from || '—'}</td>
                                            <td className="px-4 py-3">
                                                {r.official_source ? (
                                                    <a href={r.official_source} target="_blank" rel="noopener noreferrer" className="text-blue-400 hover:text-blue-300">
                                                        <ExternalLink className="w-3.5 h-3.5" />
                                                    </a>
                                                ) : <span className="text-zinc-700">—</span>}
                                            </td>
                                        </tr>
                                    ))}
                                </tbody>
                            </table>
                        </div>
                    </div>
                )}

                {/* Historical Rates Table */}
                {historicalRates.length > 0 && (
                    <div className="bg-zinc-900 border border-zinc-800 rounded-xl overflow-hidden">
                        <h3 className="px-4 py-3 bg-zinc-800/80 text-white font-medium border-b border-zinc-700">
                            Historical Rates
                            <span className="ml-2 text-xs text-red-400 font-normal">No longer current — retained for reference only</span>
                        </h3>
                        <div className="overflow-x-auto">
                            <table className="w-full text-sm text-left">
                                <thead className="bg-zinc-800/50 text-zinc-400 text-xs uppercase tracking-wide border-b border-zinc-800">
                                    <tr>
                                        <th className="px-4 py-3 w-20">Rate %</th>
                                        <th className="px-4 py-3">Rate Name</th>
                                        <th className="px-4 py-3 w-24">Eff. From</th>
                                        <th className="px-4 py-3 w-24">Eff. To</th>
                                        <th className="px-4 py-3">Notification</th>
                                        <th className="px-4 py-3 w-16">Source</th>
                                    </tr>
                                </thead>
                                <tbody className="divide-y divide-zinc-800">
                                    {historicalRates.map(r => (
                                        <tr key={r.id} className="opacity-60 hover:opacity-80">
                                            <td className="px-4 py-3 font-mono font-bold text-white text-base">{r.rate_percent}%</td>
                                            <td className="px-4 py-3 text-zinc-400">{r.rate_name}</td>
                                            <td className="px-4 py-3 text-zinc-400 text-xs">{r.effective_from || '—'}</td>
                                            <td className="px-4 py-3 text-zinc-400 text-xs">{r.effective_to || '—'}</td>
                                            <td className="px-4 py-3 text-zinc-400 text-xs font-mono">{r.notification_number || '—'}</td>
                                            <td className="px-4 py-3">
                                                {r.official_source ? (
                                                    <a href={r.official_source} target="_blank" rel="noopener noreferrer" className="text-blue-400 hover:text-blue-300">
                                                        <ExternalLink className="w-3.5 h-3.5" />
                                                    </a>
                                                ) : <span className="text-zinc-700">—</span>}
                                            </td>
                                        </tr>
                                    ))}
                                </tbody>
                            </table>
                        </div>
                    </div>
                )}

                {filtered.length === 0 && (
                    <div className="bg-zinc-900 border border-zinc-800 rounded-xl p-10 text-center text-zinc-500">
                        No rates match the current filter.
                    </div>
                )}
            </div>
        </div>
    )
}
