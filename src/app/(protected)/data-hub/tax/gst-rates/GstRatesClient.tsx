'use client'

import { useState, useMemo } from 'react'
import { AlertCircle, ExternalLink, Search, Info, X } from 'lucide-react'

type GstRate = {
    id: string
    rate_percent: number
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
    statutory_rate_percent?: number
    effective_display_percent?: number
    valuation_basis?: string
    itc_policy?: string
    conditions?: Record<string, unknown>
}

export default function GstRatesClient({ rates, dbError }: { rates: GstRate[], dbError?: string }) {
    const [search, setSearch] = useState('')
    const [statusFilter, setStatusFilter] = useState<'ALL' | 'ACTIVE' | 'INACTIVE'>('ACTIVE')
    const [view, setView] = useState<'TRANSACTION' | 'REFERENCE'>('TRANSACTION')
    const [selectedRecord, setSelectedRecord] = useState<GstRate | null>(null)

    const displayRecords = useMemo(() => {
        // First filter by view type
        const viewRates = rates.filter(r => {
            const isEligibleTx = r.usage_scope === 'TRANSACTION_RATE' && r.is_current === true && (r.erp_visibility === 'GENERAL' || r.erp_visibility === 'CONTEXT_ONLY');
            if (view === 'TRANSACTION') {
                return isEligibleTx;
            } else {
                return !isEligibleTx;
            }
        })

        // Expand into GST/IGST/Exempt
        let expanded: Array<{
            uiKey: string,
            displayName: string,
            displayRate: string,
            record: GstRate,
            isConditional: boolean,
            isEffective: boolean
        }> = []

        for (const r of viewRates) {
            const statRate = r.statutory_rate_percent ?? r.rate_percent;
            const effRate = r.effective_display_percent ?? r.rate_percent;
            const differ = statRate !== effRate;
            
            const isConditional = r.erp_visibility === 'CONTEXT_ONLY';
            const isEffective = differ;
            
            const suffix = r.conditions?.real_estate_other ? ' — Real Estate' : '';

            if (view === 'TRANSACTION') {
                if (r.category === 'EXEMPT') {
                    expanded.push({
                        uiKey: `${r.id}-exempt`,
                        displayName: 'Exempt',
                        displayRate: '—',
                        record: r,
                        isConditional,
                        isEffective
                    });
                } else {
                    expanded.push({
                        uiKey: `${r.id}-igst`,
                        displayName: `IGST@${effRate}%${suffix}`,
                        displayRate: String(effRate),
                        record: r,
                        isConditional,
                        isEffective
                    });
                    expanded.push({
                        uiKey: `${r.id}-gst`,
                        displayName: `GST@${effRate}%${suffix}`,
                        displayRate: String(effRate),
                        record: r,
                        isConditional,
                        isEffective
                    });
                }
            } else {
                expanded.push({
                    uiKey: r.id,
                    displayName: r.rate_name,
                    displayRate: String(r.rate_percent),
                    record: r,
                    isConditional: false,
                    isEffective: false
                });
            }
        }

        // Apply Search and Status Filter
        return expanded.filter(item => {
            if (statusFilter !== 'ALL' && item.record.status !== statusFilter) return false;
            
            if (search) {
                const q = search.toLowerCase();
                const rateNameMatches = item.record.rate_name.toLowerCase().includes(q);
                const displayNameMatches = item.displayName.toLowerCase().includes(q);
                return displayNameMatches || rateNameMatches;
            }
            return true;
        })
    }, [rates, view, search, statusFilter])

    return (
        <div className="space-y-6 relative">
            {/* Header */}
            <div>
                <h1 className="text-2xl font-bold text-white mb-1">GST Master</h1>
                <p className="text-zinc-400 text-sm">
                    Manage business GST, IGST and Exempt options.
                </p>
            </div>

            {dbError && (
                <div className="p-4 border border-red-500/30 bg-red-500/10 rounded-lg flex items-center gap-3 text-red-400 text-sm">
                    <AlertCircle className="w-5 h-5 shrink-0" />
                    Database error: {dbError}
                </div>
            )}

            {/* View Tabs */}
            <div className="flex gap-4 border-b border-zinc-800">
                <button 
                    onClick={() => setView('TRANSACTION')}
                    className={`pb-2 text-sm font-medium border-b-2 transition-colors ${view === 'TRANSACTION' ? 'border-teal-500 text-teal-400' : 'border-transparent text-zinc-500 hover:text-zinc-300'}`}
                >
                    Transaction Rates
                </button>
                <button 
                    onClick={() => setView('REFERENCE')}
                    className={`pb-2 text-sm font-medium border-b-2 transition-colors ${view === 'REFERENCE' ? 'border-teal-500 text-teal-400' : 'border-transparent text-zinc-500 hover:text-zinc-300'}`}
                >
                    Reference
                </button>
            </div>

            {/* Filters */}
            <div className="flex flex-wrap gap-3 items-center">
                <div className="relative flex-1 min-w-48">
                    <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-500" />
                    <input
                        type="text"
                        placeholder="Search displayed names (e.g. GST@5%)..."
                        value={search}
                        onChange={(e) => setSearch(e.target.value)}
                        className="w-full bg-zinc-900 border border-zinc-800 rounded-lg pl-9 pr-4 py-2 text-sm text-white placeholder-zinc-500 focus:outline-none focus:border-zinc-700"
                    />
                </div>
                <select
                    value={statusFilter}
                    onChange={(e) => setStatusFilter(e.target.value as any)}
                    className="bg-zinc-900 border border-zinc-800 rounded-lg px-3 py-2 text-sm text-white focus:outline-none focus:border-zinc-700 appearance-none min-w-32"
                >
                    <option value="ALL">All Status</option>
                    <option value="ACTIVE">Active</option>
                    <option value="INACTIVE">Inactive</option>
                </select>
                {(search || statusFilter !== 'ACTIVE') && (
                    <button
                        onClick={() => { setSearch(''); setStatusFilter('ACTIVE'); }}
                        className="text-sm text-zinc-400 hover:text-white px-2 py-1"
                    >
                        Clear Filters
                    </button>
                )}
            </div>

            {/* Table */}
            <div className="bg-zinc-900 border border-zinc-800 rounded-xl overflow-hidden">
                <div className="overflow-x-auto">
                    <table className="w-full text-sm text-left">
                        <thead className="bg-zinc-800/50 text-zinc-400 text-xs uppercase tracking-wide border-b border-zinc-800">
                            <tr>
                                <th className="px-4 py-3">Name</th>
                                <th className="px-4 py-3 w-32">Rate (%)</th>
                                <th className="px-4 py-3 w-32">Status</th>
                                <th className="px-4 py-3 w-24 text-right">Actions</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-zinc-800">
                            {displayRecords.map(item => (
                                <tr key={item.uiKey} className="hover:bg-zinc-800/30">
                                    <td className="px-4 py-3">
                                        <div className="flex items-center gap-2">
                                            <span className="font-mono font-bold text-white text-base">{item.displayName}</span>
                                            {item.isConditional && (
                                                <span className="px-1.5 py-0.5 rounded bg-amber-500/10 text-amber-400 text-[10px] uppercase font-bold tracking-wider">
                                                    Conditional
                                                </span>
                                            )}
                                            {item.isEffective && (
                                                <span className="px-1.5 py-0.5 rounded bg-blue-500/10 text-blue-400 text-[10px] uppercase font-bold tracking-wider">
                                                    Effective
                                                </span>
                                            )}
                                        </div>
                                    </td>
                                    <td className="px-4 py-3 font-mono font-medium text-zinc-300">
                                        {item.displayRate}
                                    </td>
                                    <td className="px-4 py-3">
                                        <span className={`px-2 py-0.5 rounded-full text-xs ${item.record.status === 'ACTIVE' ? 'bg-green-500/10 text-green-400' : 'bg-zinc-700 text-zinc-500'}`}>
                                            {item.record.status}
                                        </span>
                                    </td>
                                    <td className="px-4 py-3 text-right">
                                        <button 
                                            onClick={() => setSelectedRecord(item.record)}
                                            className="text-teal-400 hover:text-teal-300 text-xs font-medium flex items-center gap-1 justify-end w-full"
                                        >
                                            <Info className="w-3.5 h-3.5" />
                                            Details
                                        </button>
                                    </td>
                                </tr>
                            ))}
                            {displayRecords.length === 0 && (
                                <tr>
                                    <td colSpan={4} className="p-8 text-center text-zinc-500">
                                        No options match the current filter.
                                    </td>
                                </tr>
                            )}
                        </tbody>
                    </table>
                </div>
            </div>

            {/* Details Drawer */}
            {selectedRecord && (
                <div className="fixed inset-0 z-50 flex justify-end">
                    <div 
                        className="absolute inset-0 bg-black/60 backdrop-blur-sm" 
                        onClick={() => setSelectedRecord(null)}
                    />
                    <div className="relative w-full max-w-md bg-zinc-900 border-l border-zinc-800 h-full overflow-y-auto flex flex-col shadow-2xl animate-in slide-in-from-right duration-200">
                        <div className="px-6 py-5 border-b border-zinc-800 flex justify-between items-center bg-zinc-900/95 sticky top-0 z-10">
                            <h2 className="text-lg font-bold text-white">Rate Details</h2>
                            <button 
                                onClick={() => setSelectedRecord(null)}
                                className="text-zinc-400 hover:text-white p-1 rounded-md hover:bg-zinc-800"
                            >
                                <X className="w-5 h-5" />
                            </button>
                        </div>
                        
                        <div className="p-6 space-y-6">
                            <div>
                                <label className="text-xs text-zinc-500 uppercase font-bold tracking-wider mb-1 block">Catalog Name</label>
                                <div className="text-white text-sm bg-zinc-800/50 p-3 rounded-lg border border-zinc-700/50">
                                    {selectedRecord.rate_name}
                                </div>
                            </div>
                            
                            <div className="grid grid-cols-2 gap-4">
                                <div>
                                    <label className="text-xs text-zinc-500 uppercase font-bold tracking-wider mb-1 block">Category</label>
                                    <div className="text-zinc-200 text-sm">{selectedRecord.category}</div>
                                </div>
                                <div>
                                    <label className="text-xs text-zinc-500 uppercase font-bold tracking-wider mb-1 block">ERP Visibility</label>
                                    <div className="text-zinc-200 text-sm">{selectedRecord.erp_visibility}</div>
                                </div>
                                <div>
                                    <label className="text-xs text-zinc-500 uppercase font-bold tracking-wider mb-1 block">Usage Scope</label>
                                    <div className="text-zinc-200 text-sm">{selectedRecord.usage_scope}</div>
                                </div>
                                <div>
                                    <label className="text-xs text-zinc-500 uppercase font-bold tracking-wider mb-1 block">Status</label>
                                    <div className="text-zinc-200 text-sm">{selectedRecord.status}</div>
                                </div>
                            </div>

                            <div className="border-t border-zinc-800 pt-6 grid grid-cols-2 gap-4">
                                <div>
                                    <label className="text-xs text-zinc-500 uppercase font-bold tracking-wider mb-1 block">Effective Rate</label>
                                    <div className="text-white text-sm font-mono font-medium">
                                        {selectedRecord.effective_display_percent ?? selectedRecord.rate_percent}%
                                    </div>
                                </div>
                                <div>
                                    <label className="text-xs text-zinc-500 uppercase font-bold tracking-wider mb-1 block">Statutory Rate</label>
                                    <div className="text-zinc-400 text-sm font-mono">
                                        {selectedRecord.statutory_rate_percent ?? selectedRecord.rate_percent}%
                                    </div>
                                </div>
                            </div>

                            <div className="border-t border-zinc-800 pt-6 space-y-4">
                                <div>
                                    <label className="text-xs text-zinc-500 uppercase font-bold tracking-wider mb-1 block">Valuation Basis</label>
                                    <div className="text-zinc-200 text-sm font-mono">{selectedRecord.valuation_basis || 'TRANSACTION_VALUE'}</div>
                                </div>
                                <div>
                                    <label className="text-xs text-zinc-500 uppercase font-bold tracking-wider mb-1 block">ITC Policy</label>
                                    <div className="text-zinc-200 text-sm font-mono">{selectedRecord.itc_policy || 'DEFAULT'}</div>
                                </div>
                                {selectedRecord.conditions && (
                                    <div>
                                        <label className="text-xs text-zinc-500 uppercase font-bold tracking-wider mb-1 block">Conditions</label>
                                        <pre className="text-zinc-300 text-xs font-mono bg-zinc-800 p-3 rounded-lg overflow-x-auto border border-zinc-700/50">
                                            {JSON.stringify(selectedRecord.conditions, null, 2)}
                                        </pre>
                                    </div>
                                )}
                            </div>

                            <div className="border-t border-zinc-800 pt-6 space-y-4">
                                <div className="grid grid-cols-2 gap-4">
                                    <div>
                                        <label className="text-xs text-zinc-500 uppercase font-bold tracking-wider mb-1 block">Effective From</label>
                                        <div className="text-zinc-200 text-sm">{selectedRecord.effective_from || '?"'}</div>
                                    </div>
                                    <div>
                                        <label className="text-xs text-zinc-500 uppercase font-bold tracking-wider mb-1 block">Effective To</label>
                                        <div className="text-zinc-200 text-sm">{selectedRecord.effective_to || '?"'}</div>
                                    </div>
                                    <div>
                                        <label className="text-xs text-zinc-500 uppercase font-bold tracking-wider mb-1 block">Notification</label>
                                        <div className="text-zinc-200 text-sm font-mono">{selectedRecord.notification_number || '?"'}</div>
                                    </div>
                                    {selectedRecord.official_source && (
                                        <div>
                                            <label className="text-xs text-zinc-500 uppercase font-bold tracking-wider mb-1 block">Source</label>
                                            <a href={selectedRecord.official_source} target="_blank" rel="noopener noreferrer" className="text-blue-400 hover:text-blue-300 text-sm flex items-center gap-1">
                                                View Document <ExternalLink className="w-3.5 h-3.5" />
                                            </a>
                                        </div>
                                    )}
                                </div>
                            </div>
                            
                            <div className="text-xs text-zinc-600 font-mono mt-8 border-t border-zinc-800/50 pt-4">
                                ID: {selectedRecord.id}
                            </div>
                        </div>
                    </div>
                </div>
            )}
        </div>
    )
}
