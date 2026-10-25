'use client'

import { useState, useEffect } from 'react'
import { Search, ChevronLeft, ChevronRight, AlertCircle, Edit, Plus, Check, X, Building, Briefcase } from 'lucide-react'

export default function DesignationsClient() {
    const [records, setRecords] = useState<any[]>([])
    const [total, setTotal] = useState(0)
    const [search, setSearch] = useState('')
    const [status, setStatus] = useState('ALL')
    const [page, setPage] = useState(1)
    const [loading, setLoading] = useState(false)
    const [dbError, setDbError] = useState('')
    
    // Modal states
    const [isModalOpen, setIsModalOpen] = useState(false)
    const [editingRecord, setEditingRecord] = useState<any>(null)
    const [formState, setFormState] = useState({
        code: '',
        name: '',
        description: '',
        title_mode: 'FIXED',
        title_template: ''
    })
    const [saving, setSaving] = useState(false)
    const [saveError, setSaveError] = useState('')

    const limit = 50
    const endpoint = '/api/data-hub/organization/designations'

    useEffect(() => {
        let active = true
        const fetchRecords = async () => {
            setLoading(true)
            setDbError('')
            try {
                const params = new URLSearchParams()
                params.set('limit', limit.toString())
                params.set('offset', ((page - 1) * limit).toString())
                if (search) params.set('search', search)
                if (status !== 'ALL') params.set('status', status)

                const res = await fetch(endpoint + '?' + params.toString())
                const data = await res.json()
                if (!active) return
                
                if (res.ok) {
                    setRecords(data.data || [])
                    setTotal(data.count || 0)
                } else {
                    setDbError(data.error || 'Failed to load records.')
                }
            } catch (err: any) {
                if (active) setDbError('An unexpected error occurred.')
            } finally {
                if (active) setLoading(false)
            }
        }
        
        const debounce = setTimeout(fetchRecords, 300)
        return () => { active = false; clearTimeout(debounce) }
    }, [page, search, status])

    const handleToggleStatus = async (record: any) => {
        if (dbError) return;
        try {
            const newStatus = record.status === 'ACTIVE' ? 'INACTIVE' : 'ACTIVE'
            const res = await fetch(endpoint, {
                method: 'PATCH',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ id: record.id, status: newStatus })
            })
            if (!res.ok) {
                const data = await res.json()
                throw new Error(data.error || 'Update failed')
            }
            setRecords(prev => prev.map(r => r.id === record.id ? { ...r, status: newStatus } : r))
        } catch (e: any) {
            alert(e.message)
        }
    }

    const handleSave = async () => {
        if (!formState.code || !formState.name) {
            setSaveError('Code and Name are required')
            return
        }
        setSaving(true)
        setSaveError('')
        try {
            const isEdit = !!editingRecord
            const method = isEdit ? 'PATCH' : 'POST'
            const body = isEdit 
                ? { id: editingRecord.id, ...formState }
                : { ...formState }

            const res = await fetch(endpoint, {
                method,
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(body)
            })
            
            const data = await res.json()
            if (!res.ok) throw new Error(data.error || 'Save failed')
            
            setIsModalOpen(false)
            setPage(1)
            
            const params = new URLSearchParams()
            params.set('limit', limit.toString())
            params.set('offset', '0')
            if (search) params.set('search', search)
            if (status !== 'ALL') params.set('status', status)
            const refetch = await fetch(endpoint + '?' + params.toString())
            if(refetch.ok) {
                const rData = await refetch.json()
                setRecords(rData.data || [])
                setTotal(rData.count || 0)
            }
        } catch (e: any) {
            setSaveError(e.message)
        } finally {
            setSaving(false)
        }
    }

    const openCreateModal = () => {
        setEditingRecord(null)
        setFormState({ code: '', name: '', description: '', title_mode: 'FIXED', title_template: '' })
        setSaveError('')
        setIsModalOpen(true)
    }

    const openEditModal = (record: any) => {
        setEditingRecord(record)
        setFormState({ 
            code: record.code, 
            name: record.name, 
            description: record.description || '',
            title_mode: record.title_mode || 'FIXED',
            title_template: record.title_template || ''
        })
        setSaveError('')
        setIsModalOpen(true)
    }

    const totalPages = Math.ceil(total / limit)

    return (
        <div className="space-y-6">
            <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
                <div>
                    <h1 className="text-2xl font-bold tracking-tight mb-1">Designation Master</h1>
                    <p className="text-sm text-zinc-400">Manage central catalog of designations.</p>
                </div>
                <button
                    onClick={openCreateModal}
                    className="bg-teal-600 hover:bg-teal-500 text-white px-4 py-2 rounded-lg text-sm font-medium flex items-center gap-2 transition-colors"
                >
                    <Plus className="w-4 h-4" />
                    Create Designation
                </button>
            </div>

            {dbError && (
                <div className="bg-red-500/10 border border-red-500/20 text-red-400 px-4 py-3 rounded-lg flex items-start gap-3">
                    <AlertCircle className="w-5 h-5 shrink-0 mt-0.5" />
                    <p className="text-sm">{dbError}</p>
                </div>
            )}

            <div className="bg-zinc-900 border border-zinc-800 rounded-xl overflow-hidden flex flex-col">
                <div className="p-4 border-b border-zinc-800 flex flex-col sm:flex-row gap-4">
                    <div className="relative flex-1">
                        <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-zinc-500" />
                        <input
                            type="text"
                            placeholder="Search by code or name..."
                            value={search}
                            onChange={e => { setSearch(e.target.value); setPage(1) }}
                            className="w-full bg-zinc-950 border border-zinc-800 rounded-lg pl-9 pr-4 py-2 text-sm focus:outline-none focus:border-zinc-700 transition-colors"
                        />
                    </div>
                    <select
                        value={status}
                        onChange={e => { setStatus(e.target.value); setPage(1) }}
                        className="bg-zinc-950 border border-zinc-800 rounded-lg px-3 py-2 text-sm focus:outline-none focus:border-zinc-700 transition-colors"
                    >
                        <option value="ALL">All Status</option>
                        <option value="ACTIVE">Active</option>
                        <option value="INACTIVE">Inactive</option>
                    </select>
                </div>

                <div className="overflow-x-auto min-h-[400px]">
                    <table className="w-full text-sm text-left">
                        <thead className="text-xs text-zinc-500 uppercase bg-zinc-950/50 border-b border-zinc-800">
                            <tr>
                                <th className="px-6 py-4 font-medium">Code</th>
                                <th className="px-6 py-4 font-medium">Name</th>
                                <th className="px-6 py-4 font-medium">Mode</th>
                                <th className="px-6 py-4 font-medium">Template</th>
                                <th className="px-6 py-4 font-medium">Description</th>
                                <th className="px-6 py-4 font-medium">Status</th>
                                <th className="px-6 py-4 font-medium text-right">Actions</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-zinc-800/50">
                            {loading ? (
                                <tr>
                                    <td colSpan={5} className="px-6 py-12 text-center text-zinc-500">
                                        Loading...
                                    </td>
                                </tr>
                            ) : dbError ? (
                                <tr>
                                    <td colSpan={5} className="px-6 py-12 text-center text-zinc-500">
                                        <div className="flex flex-col items-center justify-center gap-3">
                                            <AlertCircle className="w-8 h-8 text-red-500/50" />
                                            <p className="text-zinc-400">Failed to load designations.</p>
                                            <button onClick={() => setPage(page)} className="text-teal-400 hover:text-teal-300 font-medium text-sm px-3 py-1.5 rounded-lg border border-teal-500/20 hover:bg-teal-500/10 transition-colors">
                                                Retry Connection
                                            </button>
                                        </div>
                                    </td>
                                </tr>
                            ) : records.length === 0 ? (
                                <tr>
                                    <td colSpan={5} className="px-6 py-12 text-center text-zinc-500">
                                        No designations found.
                                    </td>
                                </tr>
                            ) : (
                                records.map((record) => (
                                    <tr key={record.id} className="hover:bg-zinc-800/20 transition-colors">
                                        <td className="px-6 py-4 font-mono text-zinc-300">{record.code}</td>
                                        <td className="px-6 py-4 font-medium text-white">{record.name}</td>
                                        <td className="px-6 py-4"><span className="px-2 py-1 bg-zinc-800 rounded text-xs text-zinc-300">{record.title_mode || 'FIXED'}</span></td>
                                        <td className="px-6 py-4 font-mono text-xs text-zinc-400">{record.title_template || '-'}</td>
                                        <td className="px-6 py-4 text-zinc-400 truncate max-w-[200px]">{record.description || '-'}</td>
                                        <td className="px-6 py-4">
                                            <button
                                                onClick={() => handleToggleStatus(record)}
                                                className={`inline-flex items-center gap-1.5 px-2 py-1 rounded-md text-xs font-medium border transition-colors ${record.status === 'ACTIVE' ? 'bg-teal-500/10 text-teal-400 border-teal-500/20 hover:bg-teal-500/20' : 'bg-zinc-800/50 text-zinc-400 border-zinc-700 hover:bg-zinc-700/50'}`}
                                            >
                                                {record.status === 'ACTIVE' ? <Check className="w-3 h-3" /> : <X className="w-3 h-3" />}
                                                {record.status}
                                            </button>
                                        </td>
                                        <td className="px-6 py-4 text-right">
                                            <button
                                                onClick={() => openEditModal(record)}
                                                className="p-1.5 text-zinc-400 hover:text-white hover:bg-zinc-800 rounded transition-colors"
                                                title="Edit"
                                            >
                                                <Edit className="w-4 h-4" />
                                            </button>
                                        </td>
                                    </tr>
                                ))
                            )}
                        </tbody>
                    </table>
                </div>

                {!dbError && (<div className="p-4 border-t border-zinc-800 flex items-center justify-between text-sm text-zinc-400 bg-zinc-950/50">
                    <div>
                        Showing {records.length > 0 ? ((page - 1) * limit) + 1 : 0} to {Math.min(page * limit, total)} of {total} entries
                    </div>
                    <div className="flex items-center gap-2">
                        <button
                            onClick={() => setPage(p => Math.max(1, p - 1))}
                            disabled={page === 1 || loading}
                            className="p-1 rounded hover:bg-zinc-800 disabled:opacity-50 transition-colors"
                        >
                            <ChevronLeft className="w-5 h-5" />
                        </button>
                        <span className="px-2 font-medium text-zinc-300">
                            Page {page} of {Math.max(1, totalPages)}
                        </span>
                        <button
                            onClick={() => setPage(p => Math.min(totalPages, p + 1))}
                            disabled={page === totalPages || totalPages === 0 || loading}
                            className="p-1 rounded hover:bg-zinc-800 disabled:opacity-50 transition-colors"
                        >
                            <ChevronRight className="w-5 h-5" />
                        </button>
                    </div>
                </div>)}
            </div>

            {isModalOpen && (
                <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm">
                    <div className="bg-zinc-900 border border-zinc-800 rounded-xl w-full max-w-md shadow-2xl overflow-hidden">
                        <div className="px-6 py-4 border-b border-zinc-800 flex justify-between items-center bg-zinc-950/50">
                            <h3 className="text-lg font-semibold text-white">
                                {editingRecord ? 'Edit Designation' : 'Create Designation'}
                            </h3>
                            <button onClick={() => setIsModalOpen(false)} className="text-zinc-400 hover:text-white transition-colors">
                                <X className="w-5 h-5" />
                            </button>
                        </div>
                        <div className="p-6 space-y-4">
                            {saveError && (
                                <div className="bg-red-500/10 border border-red-500/20 text-red-400 px-3 py-2 rounded-lg text-sm">
                                    {saveError}
                                </div>
                            )}
                            <div>
                                <label className="block text-sm font-medium text-zinc-400 mb-1.5">Unique Code</label>
                                <input
                                    type="text"
                                    value={formState.code}
                                    onChange={e => setFormState({ ...formState, code: e.target.value.toUpperCase() })}
                                    placeholder="e.g. ENG"
                                    className="w-full bg-zinc-950 border border-zinc-800 rounded-lg px-3 py-2 text-sm text-white focus:outline-none focus:border-teal-500 transition-colors font-mono"
                                />
                            </div>
                            <div>
                                <label className="block text-sm font-medium text-zinc-400 mb-1.5">Name</label>
                                <input
                                    type="text"
                                    value={formState.name}
                                    onChange={e => setFormState({ ...formState, name: e.target.value })}
                                    placeholder="e.g. Engineering"
                                    className="w-full bg-zinc-950 border border-zinc-800 rounded-lg px-3 py-2 text-sm text-white focus:outline-none focus:border-teal-500 transition-colors"
                                />
                            </div>
                            <div>
                                <label className="block text-sm font-medium text-zinc-400 mb-1.5">Title Mode</label>
                                <select
                                    value={formState.title_mode}
                                    onChange={e => setFormState({ ...formState, title_mode: e.target.value })}
                                    className="w-full bg-zinc-950 border border-zinc-800 rounded-lg px-3 py-2 text-sm text-white focus:outline-none focus:border-teal-500 transition-colors"
                                >
                                    <option value="FIXED">Fixed (e.g. Chief Executive Officer)</option>
                                    <option value="DEPARTMENT_BASED">Department Based (e.g. {'{department}'} Officer)</option>
                                </select>
                            </div>
                            {formState.title_mode === 'DEPARTMENT_BASED' && (
                                <div>
                                    <label className="block text-sm font-medium text-zinc-400 mb-1.5">Title Template</label>
                                    <input
                                        type="text"
                                        value={formState.title_template}
                                        onChange={e => setFormState({ ...formState, title_template: e.target.value })}
                                        placeholder="e.g. Senior {department} Manager"
                                        className="w-full bg-zinc-950 border border-zinc-800 rounded-lg px-3 py-2 text-sm text-white focus:outline-none focus:border-teal-500 transition-colors"
                                    />
                                    <p className="text-xs text-zinc-500 mt-1">Must include '{'{department}'}' placeholder.</p>
                                    {formState.title_template && (
                                        <div className="mt-2 p-2 bg-zinc-950 border border-zinc-800 rounded text-xs text-zinc-400">
                                            Preview: <span className="text-teal-400 font-medium">{formState.title_template.replace('{department}', 'Sales')}</span>
                                        </div>
                                    )}
                                </div>
                            )}
                            <div>
                                <label className="block text-sm font-medium text-zinc-400 mb-1.5">Description (Optional)</label>
                                <textarea
                                    value={formState.description}
                                    onChange={e => setFormState({ ...formState, description: e.target.value })}
                                    placeholder="Brief description..."
                                    rows={3}
                                    className="w-full bg-zinc-950 border border-zinc-800 rounded-lg px-3 py-2 text-sm text-white focus:outline-none focus:border-teal-500 transition-colors resize-none"
                                />
                            </div>
                        </div>
                        <div className="px-6 py-4 border-t border-zinc-800 flex justify-end gap-3 bg-zinc-950/50">
                            <button
                                onClick={() => setIsModalOpen(false)}
                                disabled={saving}
                                className="px-4 py-2 rounded-lg text-sm font-medium text-zinc-300 hover:text-white hover:bg-zinc-800 transition-colors disabled:opacity-50"
                            >
                                Cancel
                            </button>
                            <button
                                onClick={handleSave}
                                disabled={saving}
                                className="px-4 py-2 rounded-lg text-sm font-medium bg-teal-600 hover:bg-teal-500 text-white transition-colors disabled:opacity-50 flex items-center gap-2"
                            >
                                {saving ? 'Saving...' : 'Save'}
                            </button>
                        </div>
                    </div>
                </div>
            )}
        </div>
    )
}
