import fs from 'fs'

const code = `'use client'

import { useState, useEffect } from 'react'
import { Search, ChevronLeft, ChevronRight, AlertCircle, Package, Edit, Plus, Check, X } from 'lucide-react'

export default function UnitsClient({
    initialUnits,
    initialTotal,
    dbError,
}: {
    initialUnits: any[]
    initialTotal: number
    dbError?: string
}) {
    const [units, setUnits] = useState(initialUnits)
    const [total, setTotal] = useState(initialTotal)
    const [search, setSearch] = useState('')
    const [status, setStatus] = useState('ACTIVE')
    const [page, setPage] = useState(1)
    const [loading, setLoading] = useState(false)
    
    // Modal states
    const [isModalOpen, setIsModalOpen] = useState(false)
    const [editingUnit, setEditingUnit] = useState<any>(null)
    const [formState, setFormState] = useState({
        business_name: '',
        short_name: '',
        aliases: ''
    })
    const [formLoading, setFormLoading] = useState(false)
    const [formError, setFormError] = useState('')

    const limit = 100

    useEffect(() => {
        let active = true
        const fetchUnits = async () => {
            setLoading(true)
            try {
                const params = new URLSearchParams()
                params.set('limit', limit.toString())
                params.set('offset', ((page - 1) * limit).toString())
                // Only Business Units shown in this view
                params.set('is_business', 'true')
                
                if (search) params.set('search', search)
                if (status !== 'ALL') params.set('status', status)

                const res = await fetch('/api/data-hub/units?' + params.toString())
                const data = await res.json()
                if (!active) return
                
                if (data.data) {
                    setUnits(data.data)
                    setTotal(data.count)
                }
            } catch (err) {
                console.error(err)
            } finally {
                if (active) setLoading(false)
            }
        }
        fetchUnits()
        return () => { active = false }
    }, [page, search, status])

    const handleToggleStatus = async (unit: any) => {
        try {
            const newStatus = unit.status === 'ACTIVE' ? 'INACTIVE' : 'ACTIVE'
            const res = await fetch('/api/data-hub/units', {
                method: 'PATCH',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ id: unit.id, status: newStatus })
            })
            if (!res.ok) throw new Error('Update failed')
            setUnits(units.map(u => u.id === unit.id ? { ...u, status: newStatus } : u))
        } catch (e) {
            console.error(e)
            alert('Failed to update status.')
        }
    }

    const openEditModal = (unit: any) => {
        setEditingUnit(unit)
        setFormState({
            business_name: unit.business_name || '',
            short_name: unit.short_name || '',
            aliases: Array.isArray(unit.aliases) ? unit.aliases.join(', ') : (unit.aliases || '')
        })
        setFormError('')
        setIsModalOpen(true)
    }

    const openAddModal = () => {
        setEditingUnit(null)
        setFormState({ business_name: '', short_name: '', aliases: '' })
        setFormError('')
        setIsModalOpen(true)
    }

    const handleSave = async (e: React.FormEvent) => {
        e.preventDefault()
        setFormError('')
        setFormLoading(true)

        try {
            const url = '/api/data-hub/units'
            const method = editingUnit ? 'PATCH' : 'POST'
            const aliasesArray = formState.aliases.split(',').map(s => s.trim()).filter(Boolean)
            
            const body = editingUnit 
                ? { id: editingUnit.id, business_name: formState.business_name, short_name: formState.short_name, aliases: aliasesArray }
                : { business_name: formState.business_name, short_name: formState.short_name, aliases: aliasesArray }

            const res = await fetch(url, {
                method,
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(body)
            })

            const data = await res.json()
            if (!res.ok) throw new Error(data.error || 'Operation failed')

            // Update local state gracefully if possible, or trigger refetch
            if (editingUnit) {
                setUnits(units.map(u => u.id === editingUnit.id ? { ...u, ...data } : u))
            } else {
                // To display the newly added active item immediately if it matches filters
                if (status === 'ACTIVE' || status === 'ALL') {
                    setUnits([data, ...units].slice(0, limit))
                    setTotal(t => t + 1)
                }
            }
            setIsModalOpen(false)
        } catch (err: any) {
            setFormError(err.message)
        } finally {
            setFormLoading(false)
        }
    }

    return (
        <div className="p-6 max-w-7xl mx-auto space-y-6 relative">
            <div className="flex items-center justify-between">
                <div>
                    <h1 className="text-2xl font-semibold text-white">Business Units Master</h1>
                    <p className="text-sm text-zinc-400 mt-1">Manage unified business units for sales, purchasing and inventory.</p>
                </div>
                <button
                    onClick={openAddModal}
                    className="flex items-center gap-2 bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-md text-sm font-medium transition-colors"
                >
                    <Plus className="w-4 h-4" />
                    Add Business Unit
                </button>
            </div>

            {dbError && (
                <div className="rounded-md bg-red-50 p-4 flex items-start">
                    <AlertCircle className="h-5 w-5 text-red-400 mt-0.5" />
                    <div className="ml-3 text-sm text-red-700">{dbError}</div>
                </div>
            )}

            <div className="bg-white rounded-lg border border-gray-200 shadow-sm overflow-hidden">
                <div className="p-4 border-b border-gray-200 flex flex-col sm:flex-row gap-4 items-center justify-between">
                    <div className="relative flex-1 max-w-md w-full">
                        <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
                        <input
                            type="text"
                            placeholder="Search by name, short name, aliases..."
                            value={search}
                            onChange={(e) => { setSearch(e.target.value); setPage(1); }}
                            className="w-full pl-9 pr-4 py-2 bg-white text-gray-900 placeholder:text-gray-500 border border-gray-300 rounded-md text-sm focus:ring-2 focus:ring-blue-500 outline-none"
                        />
                    </div>
                    <div className="flex gap-2 w-full sm:w-auto items-center">
                        <select
                            value={status}
                            onChange={(e) => { setStatus(e.target.value); setPage(1); }}
                            className="bg-white text-gray-900 border border-gray-300 rounded-md text-sm py-2 pl-3 pr-8 focus:ring-2 focus:ring-blue-500 outline-none"
                        >
                            <option value="ALL">All Status</option>
                            <option value="ACTIVE">Active</option>
                            <option value="INACTIVE">Inactive</option>
                        </select>
                        <button
                            onClick={() => { setSearch(''); setStatus('ACTIVE'); setPage(1); }}
                            className="text-sm font-medium text-gray-600 hover:text-gray-900 px-2 py-2 border border-transparent"
                        >
                            Clear Filters
                        </button>
                    </div>
                </div>

                <div className="overflow-x-auto relative min-h-[400px]">
                    {loading && (
                        <div className="absolute inset-0 bg-white/50 backdrop-blur-sm flex items-center justify-center z-10">
                            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
                        </div>
                    )}
                    <table className="w-full text-left text-sm whitespace-nowrap">
                        <thead className="bg-gray-50 border-b border-gray-200 text-gray-500">
                            <tr>
                                <th className="px-6 py-3 font-medium">UNIT NAME</th>
                                <th className="px-6 py-3 font-medium">SHORT NAME</th>
                                <th className="px-6 py-3 font-medium text-right">STATUS</th>
                                <th className="px-6 py-3 font-medium text-right">ACTIONS</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-gray-200">
                            {units.length === 0 ? (
                                <tr>
                                    <td colSpan={4} className="px-6 py-12 text-center text-gray-500">
                                        <Package className="mx-auto h-12 w-12 text-gray-300 mb-3" />
                                        <p>No business units found matching your criteria.</p>
                                    </td>
                                </tr>
                            ) : (
                                units.map((u) => (
                                    <tr key={u.id} className="hover:bg-gray-50">
                                        <td className="px-6 py-4">
                                            <div className="font-medium text-gray-900 uppercase">{u.business_name || u.name}</div>
                                            {u.name && u.business_name && u.business_name.toLowerCase() !== u.name.toLowerCase() && (
                                                <div className="text-gray-500 text-xs">Official: {u.name}</div>
                                            )}
                                        </td>
                                        <td className="px-6 py-4">
                                            <div className="text-gray-900 font-medium">{u.short_name || '-'}</div>
                                            {u.symbol && (
                                                <div className="text-gray-500 text-xs">Symbol: {u.symbol}</div>
                                            )}
                                        </td>
                                        <td className="px-6 py-4 text-right">
                                            <span className={"inline-flex items-center px-2 py-0.5 rounded text-xs font-medium " + (u.status === 'ACTIVE' ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800')}>
                                                {u.status}
                                            </span>
                                        </td>
                                        <td className="px-6 py-4 text-right">
                                            <div className="flex items-center justify-end gap-2">
                                                <button 
                                                    onClick={() => openEditModal(u)}
                                                    className="p-1.5 text-gray-500 hover:text-blue-600 hover:bg-blue-50 rounded"
                                                    title="Edit Unit"
                                                >
                                                    <Edit className="w-4 h-4" />
                                                </button>
                                                <button 
                                                    onClick={() => handleToggleStatus(u)}
                                                    className={\`p-1.5 rounded \${u.status === 'ACTIVE' ? 'text-red-500 hover:bg-red-50' : 'text-green-600 hover:bg-green-50'}\`}
                                                    title={u.status === 'ACTIVE' ? 'Deactivate' : 'Activate'}
                                                >
                                                    {u.status === 'ACTIVE' ? <X className="w-4 h-4" /> : <Check className="w-4 h-4" />}
                                                </button>
                                            </div>
                                        </td>
                                    </tr>
                                ))
                            )}
                        </tbody>
                    </table>
                </div>

                <div className="px-6 py-4 border-t border-gray-200 flex items-center justify-between text-sm">
                    <div className="text-gray-500">
                        Showing {total > 0 ? (page - 1) * limit + 1 : 0} to {Math.min(page * limit, total)} of {total} results
                    </div>
                    <div className="flex gap-2">
                        <button
                            disabled={page === 1}
                            onClick={() => setPage(p => p - 1)}
                            className="p-1 rounded hover:bg-gray-100 disabled:opacity-50 border border-gray-300"
                        >
                            <ChevronLeft className="h-5 w-5" />
                        </button>
                        <button
                            disabled={page * limit >= total}
                            onClick={() => setPage(p => p + 1)}
                            className="p-1 rounded hover:bg-gray-100 disabled:opacity-50 border border-gray-300"
                        >
                            <ChevronRight className="h-5 w-5" />
                        </button>
                    </div>
                </div>
            </div>

            {/* Modal */}
            {isModalOpen && (
                <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50">
                    <div className="bg-white rounded-lg shadow-xl w-full max-w-md overflow-hidden">
                        <div className="px-6 py-4 border-b border-gray-200 flex items-center justify-between">
                            <h2 className="text-lg font-semibold text-gray-900">
                                {editingUnit ? 'Edit Business Unit' : 'Add Business Unit'}
                            </h2>
                            <button onClick={() => setIsModalOpen(false)} className="text-gray-400 hover:text-gray-600">
                                <X className="w-5 h-5" />
                            </button>
                        </div>
                        
                        <form onSubmit={handleSave} className="p-6 space-y-4">
                            {formError && (
                                <div className="p-3 text-sm text-red-600 bg-red-50 rounded-md">
                                    {formError}
                                </div>
                            )}
                            
                            <div>
                                <label className="block text-sm font-medium text-gray-700 mb-1">Business Name (e.g. BAGS)</label>
                                <input 
                                    type="text" 
                                    required
                                    value={formState.business_name}
                                    onChange={e => setFormState({...formState, business_name: e.target.value})}
                                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-black"
                                    placeholder="Business Name"
                                />
                            </div>
                            
                            <div>
                                <label className="block text-sm font-medium text-gray-700 mb-1">Short Name (e.g. Bag)</label>
                                <input 
                                    type="text" 
                                    required
                                    value={formState.short_name}
                                    onChange={e => setFormState({...formState, short_name: e.target.value})}
                                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-black"
                                    placeholder="Short Name"
                                />
                            </div>

                            <div>
                                <label className="block text-sm font-medium text-gray-700 mb-1">Search Aliases (Comma separated)</label>
                                <input 
                                    type="text" 
                                    value={formState.aliases}
                                    onChange={e => setFormState({...formState, aliases: e.target.value})}
                                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-black"
                                    placeholder="e.g. BGS, sack"
                                />
                            </div>
                            
                            <div className="pt-4 flex justify-end gap-3">
                                <button
                                    type="button"
                                    onClick={() => setIsModalOpen(false)}
                                    className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
                                >
                                    Cancel
                                </button>
                                <button
                                    type="submit"
                                    disabled={formLoading}
                                    className="px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-md hover:bg-blue-700 disabled:opacity-50"
                                >
                                    {formLoading ? 'Saving...' : 'Save'}
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            )}
        </div>
    )
}
`
fs.writeFileSync('src/app/(protected)/data-hub/units/UnitsClient.tsx', code)
