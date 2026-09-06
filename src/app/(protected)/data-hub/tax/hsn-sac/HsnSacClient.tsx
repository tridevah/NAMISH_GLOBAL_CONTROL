'use client'

import { useState, useEffect } from 'react'
import { Hash, AlertCircle, Search, ExternalLink, ChevronLeft, ChevronRight } from 'lucide-react'

const TYPE_COLORS: Record<string, string> = { HSN: 'bg-teal-500/10 text-teal-400', SAC: 'bg-blue-500/10 text-blue-400' }
const GS_COLORS: Record<string, string> = { GOODS: 'bg-emerald-500/10 text-emerald-400', SERVICE: 'bg-purple-500/10 text-purple-400' }

export default function HsnSacClient({
    initialCodes,
    initialTotal,
    hsnCount,
    sacCount,
    dbError,
}: {
    initialCodes: any[]
    initialTotal: number
    hsnCount: number
    sacCount: number
    dbError?: string
}) {
    const [codes, setCodes] = useState(initialCodes)
    const [total, setTotal] = useState(initialTotal)

    const [search, setSearch] = useState('')
    const [typeFilter, setType] = useState<'ALL' | 'HSN' | 'SAC'>('ALL')
    const [gsFilter, setGs] = useState<'ALL' | 'GOODS' | 'SERVICE'>('ALL')
    const [levelFilter, setLevelFilter] = useState<'ALL' | 'TOP_LEVEL' | 'DETAILED'>('ALL')

    const [page, setPage] = useState(1)
    const [loading, setLoading] = useState(false)
    const limit = 100

    useEffect(() => {
        let active = true
        const fetchCodes = async () => {
            setLoading(true)
            try {
                const params = new URLSearchParams()
                params.set('limit', limit.toString())
                params.set('offset', ((page - 1) * limit).toString())
                if (search) params.set('search', search)
                if (typeFilter !== 'ALL') params.set('code_type', typeFilter)
                if (gsFilter !== 'ALL') params.set('goods_or_service', gsFilter)
                if (levelFilter === 'TOP_LEVEL') params.set('status', 'TOP_LEVEL_CLASSIFICATION_ONLY')
                if (levelFilter === 'DETAILED') params.set('status', 'ACTIVE')

                const res = await fetch('/api/data-hub/tax/hsn-sac?' + params.toString())
                const data = await res.json()
                if (active && data.data) {
                    setCodes(data.data)
                    setTotal(data.total)
                }
            } catch (err) {
                console.error(err)
            }
            setLoading(false)
        }
        fetchCodes()
        return () => { active = false }
    }, [search, typeFilter, gsFilter, levelFilter, page])

    const totalPages = Math.ceil(total / limit) || 1

    return (
        <div className="space-y-6">
            <div>
                <h1 className="text-2xl font-bold text-white flex items-center gap-2 mb-1">
                    <Hash className="w-6 h-6 text-teal-400" />
                    HSN / SAC Code Master
                </h1>
                <p className="text-zinc-400 text-sm mb-4">
                    Harmonised System of Nomenclature (HSN) and Services Accounting Codes (SAC).
                </p>

                {/* Summary Cards — counts from server-side code_type filters */}
                <div className="grid grid-cols-3 gap-4 max-w-xl mb-6">
                    <div className="bg-zinc-900 border border-zinc-800 p-4 rounded-lg">
                        <div className="text-zinc-400 text-xs uppercase tracking-wide mb-1">HSN Codes</div>
                        <div className="text-2xl font-bold text-teal-400">{hsnCount.toLocaleString()}</div>
                    </div>
                    <div className="bg-zinc-900 border border-zinc-800 p-4 rounded-lg">
                        <div className="text-zinc-400 text-xs uppercase tracking-wide mb-1">SAC Codes</div>
                        <div className="text-2xl font-bold text-blue-400">{sacCount.toLocaleString()}</div>
                    </div>
                    <div className="bg-zinc-900 border border-zinc-800 p-4 rounded-lg">
                        <div className="text-zinc-400 text-xs uppercase tracking-wide mb-1">Total Codes</div>
                        <div className="text-2xl font-bold text-white">{(hsnCount + sacCount).toLocaleString()}</div>
                    </div>
                </div>
            </div>

            {dbError && (
                <div className="p-4 border border-red-500/30 bg-red-500/10 rounded-lg flex items-center gap-3 text-red-400 text-sm">
                    <AlertCircle className="w-5 h-5 shrink-0" />
                    Database error: {dbError}
                </div>
            )}

            <div className="flex flex-wrap gap-4 items-center bg-zinc-900/50 p-4 rounded-xl border border-zinc-800">
                <div className="relative flex-1 min-w-[200px]">
                    <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-zinc-500" />
                    <input
                        type="text"
                        placeholder="Search code or description..."
                        value={search}
                        onChange={e => { setSearch(e.target.value); setPage(1); }}
                        className="w-full bg-zinc-950 border border-zinc-800 rounded-lg py-2 pl-10 pr-4 text-sm text-white placeholder:text-zinc-600 focus:outline-none focus:border-teal-500/50"
                    />
                </div>

                <select value={typeFilter} onChange={e => { setType(e.target.value as any); setPage(1); }}
                    className="bg-zinc-950 border border-zinc-800 rounded-lg px-3 py-2 text-sm text-zinc-300">
                    <option value="ALL">All Types</option>
                    <option value="HSN">HSN Only</option>
                    <option value="SAC">SAC Only</option>
                </select>

                <select value={gsFilter} onChange={e => { setGs(e.target.value as any); setPage(1); }}
                    className="bg-zinc-950 border border-zinc-800 rounded-lg px-3 py-2 text-sm text-zinc-300">
                    <option value="ALL">Goods &amp; Services</option>
                    <option value="GOODS">Goods Only</option>
                    <option value="SERVICE">Services Only</option>
                </select>

                <select value={levelFilter} onChange={e => { setLevelFilter(e.target.value as any); setPage(1); }}
                    className="bg-zinc-950 border border-zinc-800 rounded-lg px-3 py-2 text-sm text-zinc-300">
                    <option value="ALL">All Levels</option>
                    <option value="TOP_LEVEL">Top-Level Only</option>
                    <option value="DETAILED">Detailed Codes</option>
                </select>

                <span className="text-zinc-500 text-sm ml-auto">{total.toLocaleString()} codes found</span>
            </div>

            <div className="bg-zinc-900 border border-zinc-800 rounded-xl overflow-hidden">
                <div className="overflow-x-auto">
                    <table className="w-full text-sm text-left">
                        <thead className="bg-zinc-800/50 text-zinc-400 text-xs uppercase tracking-wide">
                            <tr>
                                <th className="px-4 py-3 w-24">Code</th>
                                <th className="px-4 py-3 w-16">Type</th>
                                <th className="px-4 py-3 w-20">Category</th>
                                <th className="px-4 py-3 w-16">Chapter</th>
                                <th className="px-4 py-3">Description</th>
                                <th className="px-4 py-3 w-24">Eff. From</th>
                                <th className="px-4 py-3 w-16">Source</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-zinc-800 relative">
                            {loading && (
                                <tr>
                                    <td colSpan={7} className="px-4 py-10 text-center text-zinc-500">Loading...</td>
                                </tr>
                            )}
                            {!loading && codes.length === 0 && (
                                <tr>
                                    <td colSpan={7} className="px-4 py-10 text-center text-zinc-500">No codes found.</td>
                                </tr>
                            )}
                            {!loading && codes.map(c => (
                                <tr key={c.id} className="hover:bg-zinc-800/30">
                                    <td className="px-4 py-3 font-mono text-white font-semibold">{c.code}</td>
                                    <td className="px-4 py-3"><span className={`px-2 py-0.5 rounded text-xs font-mono ${TYPE_COLORS[c.code_type] || 'bg-zinc-800 text-zinc-400'}`}>{c.code_type}</span></td>
                                    <td className="px-4 py-3"><span className={`px-2 py-0.5 rounded-full text-[10px] font-bold tracking-wider ${GS_COLORS[c.goods_or_service] || 'bg-zinc-800 text-zinc-400'}`}>{c.goods_or_service}</span></td>
                                    <td className="px-4 py-3 font-mono text-zinc-400">{c.chapter || '—'}</td>
                                    <td className="px-4 py-3 text-zinc-300">{c.description}</td>
                                    <td className="px-4 py-3 text-zinc-400 text-xs">{c.effective_from || '—'}</td>
                                    <td className="px-4 py-3">
                                        {c.official_source ? (
                                            <a href={c.official_source} target="_blank" rel="noopener noreferrer" className="text-blue-400 hover:text-blue-300"><ExternalLink className="w-3.5 h-3.5" /></a>
                                        ) : <span className="text-zinc-700">—</span>}
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>

                {/* Pagination Controls */}
                <div className="p-4 border-t border-zinc-800 flex items-center justify-between text-sm text-zinc-400">
                    <div>
                        Showing {total === 0 ? 0 : (page - 1) * limit + 1} to {Math.min(page * limit, total)} of {total.toLocaleString()}
                    </div>
                    <div className="flex items-center gap-2">
                        <button
                            disabled={page === 1 || loading}
                            onClick={() => setPage(p => p - 1)}
                            className="p-1 hover:bg-zinc-800 rounded disabled:opacity-50 disabled:hover:bg-transparent"
                        >
                            <ChevronLeft className="w-5 h-5" />
                        </button>
                        <span className="px-2">Page {page} of {totalPages}</span>
                        <button
                            disabled={page >= totalPages || loading}
                            onClick={() => setPage(p => p + 1)}
                            className="p-1 hover:bg-zinc-800 rounded disabled:opacity-50 disabled:hover:bg-transparent"
                        >
                            <ChevronRight className="w-5 h-5" />
                        </button>
                    </div>
                </div>
            </div>
        </div>
    )
}
