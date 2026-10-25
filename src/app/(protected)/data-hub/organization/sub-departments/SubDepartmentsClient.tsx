'use client'

import { useState, useEffect, useRef, useCallback } from 'react'
import { Search, ChevronLeft, ChevronRight, AlertCircle, Edit, Plus, Check, X, Users, RefreshCw } from 'lucide-react'
import { DesignationMappingModal } from './DesignationMappingModal'

export default function SubDepartmentsClient() {
    const [records, setRecords] = useState<any[]>([])
    const [total, setTotal] = useState(0)
    const [search, setSearch] = useState('')
    const [status, setStatus] = useState('ALL')
    const [filterDept, setFilterDept] = useState('')
    const [page, setPage] = useState(1)
    const [loading, setLoading] = useState(false)
    const [dbError, setDbError] = useState('')
    const [refreshError, setRefreshError] = useState(false)
    const [isRetryingRefresh, setIsRetryingRefresh] = useState(false)
    
    // Modal states
    const [isModalOpen, setIsModalOpen] = useState(false)
    const [allDepartments, setAllDepartments] = useState<any[]>([])
    const [departmentsError, setDepartmentsError] = useState('')
    const [isDepartmentsLoaded, setIsDepartmentsLoaded] = useState(false)
    const [editingRecord, setEditingRecord] = useState<any>(null)
    const [formState, setFormState] = useState({
        code: '',
        name: '',
        department_id: '',
        description: '',
        title_display_name: '',
        status: 'ACTIVE'
    })
    const [saving, setSaving] = useState(false)
    const [saveError, setSaveError] = useState('')
    const [mappingRecord, setMappingRecord] = useState<any>(null)
    
    const abortControllerRef = useRef<AbortController | null>(null)
    const deptAbortControllerRef = useRef<AbortController | null>(null)

    const limit = 50
    const endpoint = '/api/data-hub/organization/sub-departments'

    const fetchDepartments = useCallback(async () => {
        if (deptAbortControllerRef.current) deptAbortControllerRef.current.abort()
        const abortController = new AbortController()
        deptAbortControllerRef.current = abortController

        setDepartmentsError('')
        try {
            const res = await fetch('/api/data-hub/organization/departments?limit=1000', { signal: abortController.signal })
            const d = await res.json()
            if (!res.ok) throw new Error(d.error || 'Failed to fetch departments')
            if (!Array.isArray(d.data)) throw new Error('Invalid response shape for departments')
            setAllDepartments(d.data)
            setIsDepartmentsLoaded(true)
        } catch (e: any) {
            if (e.name !== 'AbortError') {
                console.error(e)
                setDepartmentsError(e.message)
                setIsDepartmentsLoaded(false)
            }
        }
    }, [])

    useEffect(() => { fetchDepartments() }, [fetchDepartments])

    const fetchRecords = useCallback(async (forcedPage?: number, isRetryRefresh = false) => {
        if (abortControllerRef.current) abortControllerRef.current.abort()
        const abortController = new AbortController()
        abortControllerRef.current = abortController

        const targetPage = forcedPage !== undefined ? forcedPage : page

        if (isRetryRefresh) setIsRetryingRefresh(true)
        else setLoading(true)
        
        setDbError('')
        
        try {
            const params = new URLSearchParams()
            params.set('limit', limit.toString())
            params.set('offset', ((targetPage - 1) * limit).toString())
            if (search) params.set('search', search)
            if (status !== 'ALL') params.set('status', status)
            if (filterDept) params.set('department_id', filterDept)

            const res = await fetch(`${endpoint}?${params.toString()}`, { signal: abortController.signal })
            const data = await res.json()

            if (!res.ok) {
                if (res.status === 503) {
                    throw new Error('Database schema missing or incompatible. Please apply pending migrations.')
                }
                throw new Error(data.error || 'Failed to fetch records')
            }
            setRecords(data.data || [])
            setTotal(data.count || 0)
            if (forcedPage !== undefined && forcedPage !== page) {
                setPage(forcedPage)
            }
            // Only clear refresh error ON SUCCESS
            setRefreshError(false)
        } catch (err: any) {
            if (err.name !== 'AbortError') {
                if (!isRetryRefresh) setDbError(err.message)
            }
            throw err // Propagate error explicitly to caller
        } finally {
            if (isRetryRefresh) setIsRetryingRefresh(false)
            else setLoading(false)
        }
    }, [page, search, status, filterDept, limit, endpoint])

    // Reset pagination when filters change
    useEffect(() => {
        setPage(1)
    }, [search, status, filterDept])

    // Main fetch effect
    useEffect(() => {
        fetchRecords().catch(() => {})
        return () => {
            if (abortControllerRef.current) abortControllerRef.current.abort()
        }
    }, [fetchRecords])

    const totalPages = Math.ceil(total / limit)

    const openCreateModal = () => {
        setEditingRecord(null)
        setFormState({ 
            code: '', 
            name: '', 
            department_id: '',
            description: '',
            title_display_name: '',
            status: 'ACTIVE'
        })
        setSaveError('')
        setIsModalOpen(true)
    }

    const openEditModal = (record: any) => {
        setEditingRecord(record)
        setFormState({ 
            code: record.code || '', 
            name: record.name || '', 
            department_id: record.department_id || '',
            description: record.description || '',
            title_display_name: record.title_display_name || '',
            status: record.status || 'ACTIVE'
        })
        setSaveError('')
        setIsModalOpen(true)
    }

    const handleSave = async (e: React.FormEvent) => {
        e.preventDefault()
        setSaveError('')
        
        if (!formState.code || !formState.name || !formState.department_id) {
            setSaveError('Code, Name, and Parent Department are required.')
            return
        }

        setSaving(true)
        try {
            const isEdit = !!editingRecord
            const method = isEdit ? 'PATCH' : 'POST'
            let updatePayload: any = { ...formState }
            if (isEdit) updatePayload.id = editingRecord.id

            const res = await fetch(endpoint, {
                method,
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(updatePayload)
            })
            
            const data = await res.json()
            if (!res.ok) throw new Error(data.error || 'Save failed')
            
            setIsModalOpen(false)
            
            // Try to refetch
            try {
                await fetchRecords(1) // Force reset to page 1 on successful save
            } catch (err) {
                setRefreshError(true)
                // optimistic UI update just in case
                if (isEdit) {
                    setRecords(prev => prev.map(r => r.id === editingRecord.id ? data.data : r))
                } else {
                    setRecords(prev => [data.data, ...prev])
                }
            }

        } catch (err: any) {
            setSaveError(err.message)
        } finally {
            setSaving(false)
        }
    }

    return (
        <div className="flex flex-col h-full bg-[#0a0a0a] text-white overflow-hidden">
            <div className="flex-none p-6 border-b border-zinc-800">
                <div className="flex justify-between items-center mb-6">
                    <div>
                        <h1 className="text-2xl font-bold tracking-tight">Sub-department Master</h1>
                        <p className="text-zinc-400 text-sm mt-1">Manage central catalog of sub-departments.</p>
                    </div>
                    <button 
                        onClick={openCreateModal}
                        className="bg-white text-black px-4 py-2 rounded-lg font-medium hover:bg-zinc-200 transition-colors flex items-center gap-2"
                    >
                        <Plus className="w-4 h-4" />
                        Create Sub-department
                    </button>
                </div>

                <div className="flex gap-4">
                    <div className="relative flex-1 max-w-md">
                        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-500" />
                        <input
                            type="text"
                            placeholder="Search by code or name..."
                            value={search}
                            onChange={(e) => setSearch(e.target.value)}
                            className="w-full bg-zinc-900 border border-zinc-800 rounded-lg pl-10 pr-4 py-2 text-sm focus:outline-none focus:border-teal-500 transition-colors"
                        />
                    </div>
                    <select
                        value={filterDept}
                        onChange={(e) => setFilterDept(e.target.value)}
                        className="bg-zinc-900 border border-zinc-800 rounded-lg px-4 py-2 text-sm focus:outline-none focus:border-teal-500"
                    >
                        <option value="">All Departments</option>
                        {allDepartments.map(d => (
                            <option key={d.id} value={d.id}>{d.name}</option>
                        ))}
                    </select>
                    <select
                        value={status}
                        onChange={(e) => setStatus(e.target.value)}
                        className="bg-zinc-900 border border-zinc-800 rounded-lg px-4 py-2 text-sm focus:outline-none focus:border-teal-500"
                    >
                        <option value="ALL">All Status</option>
                        <option value="ACTIVE">Active</option>
                        <option value="INACTIVE">Inactive</option>
                    </select>
                </div>
            </div>

            <div className="flex-1 overflow-auto p-6">
                {refreshError && (
                    <div className="mb-4 bg-yellow-500/10 border border-yellow-500/20 rounded-lg p-4 flex items-start gap-3">
                        <AlertCircle className="w-5 h-5 text-yellow-500 shrink-0 mt-0.5" />
                        <div className="flex-1">
                            <h3 className="text-sm font-medium text-yellow-500">Saved successfully; list refresh failed</h3>
                            <button 
                                onClick={() => fetchRecords(1, true).catch(()=>{})} 
                                disabled={isRetryingRefresh}
                                className="mt-2 text-xs bg-yellow-500/20 text-yellow-400 px-3 py-1 rounded hover:bg-yellow-500/30 flex items-center gap-1 disabled:opacity-50"
                            >
                                <RefreshCw className={`w-3 h-3 ${isRetryingRefresh ? 'animate-spin' : ''}`} /> 
                                {isRetryingRefresh ? 'Retrying...' : 'Retry Refresh'}
                            </button>
                        </div>
                    </div>
                )}
                {dbError ? (
                    <div className="bg-red-500/10 border border-red-500/20 rounded-lg p-4 flex items-start gap-3">
                        <AlertCircle className="w-5 h-5 text-red-500 shrink-0 mt-0.5" />
                        <div>
                            <h3 className="text-sm font-medium text-red-500">Error Loading Data</h3>
                            <p className="text-sm text-red-400 mt-1">{dbError}</p>
                            <button onClick={() => fetchRecords().catch(()=>{})} className="mt-3 text-sm bg-red-500/20 text-red-400 px-4 py-2 rounded-lg hover:bg-red-500/30 transition-colors flex items-center gap-2">
                                <RefreshCw className="w-4 h-4" /> Retry Connection
                            </button>
                        </div>
                    </div>
                ) : loading ? (
                    <div className="flex items-center justify-center h-64">
                        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-teal-500"></div>
                    </div>
                ) : records.length === 0 ? (
                    <div className="flex flex-col items-center justify-center h-64 text-zinc-500">
                        <Users className="w-12 h-12 mb-4 opacity-20" />
                        <p>No sub-departments found matching your criteria</p>
                    </div>
                ) : (
                    <div className="border border-zinc-800 rounded-lg overflow-hidden">
                        <table className="w-full text-sm text-left">
                            <thead className="bg-zinc-900/50 text-zinc-400 border-b border-zinc-800">
                                <tr>
                                    <th className="py-3 px-4 font-medium">Code</th>
                                    <th className="py-3 px-4 font-medium">Name</th>
                                    <th className="py-3 px-4 font-medium">Parent Department</th>
                                    <th className="py-3 px-4 font-medium">Short Title</th>
                                    <th className="py-3 px-4 font-medium">Description</th>
                                    <th className="py-3 px-4 font-medium">Status</th>
                                    <th className="py-3 px-4 font-medium text-right">Actions</th>
                                </tr>
                            </thead>
                            <tbody className="divide-y divide-zinc-800/50">
                                {records.map((record) => (
                                    <tr key={record.id} className="hover:bg-zinc-900/30 transition-colors">
                                        <td className="py-3 px-4 font-medium">{record.code}</td>
                                        <td className="py-3 px-4">{record.name}</td>
                                        <td className="py-3 px-4 text-zinc-500">{allDepartments.find(d => d.id === record.department_id)?.name || 'Unknown'}</td>
                                        <td className="py-3 px-4 text-zinc-500">{record.title_display_name || '-'}</td>
                                        <td className="py-3 px-4 text-zinc-500 max-w-[200px] truncate">{record.description || '-'}</td>
                                        <td className="py-3 px-4">
                                            <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${
                                                record.status === 'ACTIVE' 
                                                    ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20' 
                                                    : 'bg-zinc-800 text-zinc-400 border border-zinc-700'
                                            }`}>
                                                {record.status}
                                            </span>
                                        </td>
                                        <td className="py-3 px-4 text-right">
                                            <button 
                                                onClick={() => setMappingRecord(record)}
                                                title="Manage Designations"
                                                className="text-zinc-400 hover:text-white p-1 rounded hover:bg-zinc-800 transition-colors mr-2"
                                            >
                                                <Users className="w-4 h-4" />
                                            </button>
                                            <button 
                                                onClick={() => openEditModal(record)}
                                                className="text-zinc-400 hover:text-white p-1 rounded hover:bg-zinc-800 transition-colors"
                                            >
                                                <Edit className="w-4 h-4" />
                                            </button>
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                )}
            </div>

            <div className="flex-none p-4 border-t border-zinc-800 flex items-center justify-between text-sm text-zinc-400">
                <div>
                    Showing {records.length > 0 ? (page - 1) * limit + 1 : 0} to {Math.min(page * limit, total)} of {total} results
                </div>
                <div className="flex items-center gap-2">
                    <button 
                        disabled={page === 1}
                        onClick={() => setPage(p => p - 1)}
                        className="p-1 rounded hover:bg-zinc-800 disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                        <ChevronLeft className="w-5 h-5" />
                    </button>
                    <span className="px-2">Page {page} of {totalPages || 1}</span>
                    <button 
                        disabled={page >= totalPages}
                        onClick={() => setPage(p => p + 1)}
                        className="p-1 rounded hover:bg-zinc-800 disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                        <ChevronRight className="w-5 h-5" />
                    </button>
                </div>
            </div>

            {/* Create/Edit Modal */}
            {isModalOpen && (
                <div className="fixed inset-0 bg-black/80 flex items-center justify-center p-4 z-50">
                    <div className="bg-[#111] border border-zinc-800 rounded-xl w-full max-w-lg overflow-hidden flex flex-col max-h-[90vh]">
                        <div className="p-4 border-b border-zinc-800 flex justify-between items-center bg-zinc-900/50">
                            <h2 className="text-lg font-semibold">{editingRecord ? 'Edit Sub-department' : 'Create Sub-department'}</h2>
                            <button onClick={() => setIsModalOpen(false)} className="text-zinc-400 hover:text-white p-1 rounded-lg hover:bg-zinc-800">
                                <X className="w-5 h-5" />
                            </button>
                        </div>
                        <div className="p-6 overflow-y-auto">
                            {saveError && (
                                <div className="mb-6 bg-red-500/10 border border-red-500/20 rounded-lg p-3 flex items-start gap-2 text-sm text-red-400">
                                    <AlertCircle className="w-4 h-4 mt-0.5 shrink-0" />
                                    <p>{saveError}</p>
                                </div>
                            )}
                            <form id="deptForm" onSubmit={handleSave} className="space-y-4">
                                <div>
                                    <label className="block text-sm font-medium text-zinc-400 mb-1.5">Parent Department <span className="text-red-500">*</span></label>
                                    <div className="relative">
                                        <select
                                            value={formState.department_id}
                                            onChange={e => setFormState({ ...formState, department_id: e.target.value })}
                                            className="w-full bg-zinc-950 border border-zinc-800 rounded-lg px-3 py-2 text-sm text-white focus:outline-none focus:border-teal-500 transition-colors"
                                            disabled={!isDepartmentsLoaded || departmentsError !== ''}
                                        >
                                            <option value="">Select Parent...</option>
                                            {!isDepartmentsLoaded && !departmentsError ? (
                                                <option value="" disabled>Loading departments...</option>
                                            ) : (
                                                allDepartments.map(d => {
                                                    const isCurrentParent = editingRecord && editingRecord.department_id === d.id;
                                                    const isDisabled = d.status === 'INACTIVE' && !isCurrentParent;
                                                    return (
                                                        <option 
                                                            key={d.id} 
                                                            value={d.id}
                                                            disabled={isDisabled} 
                                                        >
                                                            {d.name} {d.status === 'INACTIVE' ? '(Inactive)' : ''}
                                                        </option>
                                                    );
                                                })
                                            )}
                                            {editingRecord && editingRecord.department_id && !allDepartments.some(d => d.id === editingRecord.department_id) && (
                                                <option value={editingRecord.department_id}>
                                                    Unknown/Inactive Parent ({editingRecord.department_id})
                                                </option>
                                            )}
                                        </select>
                                        {departmentsError && (
                                            <div className="text-xs text-red-500 mt-1 flex items-center justify-between">
                                                <span>Error loading departments.</span>
                                                <button type="button" onClick={() => fetchDepartments()} className="text-red-400 hover:text-red-300 underline">Retry</button>
                                            </div>
                                        )}
                                    </div>
                                </div>
                                <div>
                                    <label className="block text-sm font-medium text-zinc-400 mb-1.5">Code <span className="text-red-500">*</span></label>
                                    <input
                                        type="text"
                                        required
                                        value={formState.code}
                                        onChange={e => setFormState({ ...formState, code: e.target.value.toUpperCase() })}
                                        className="w-full bg-zinc-950 border border-zinc-800 rounded-lg px-3 py-2 text-sm text-white focus:outline-none focus:border-teal-500 transition-colors uppercase placeholder:normal-case"
                                        placeholder="e.g. SUB_DEPT_ENG"
                                    />
                                </div>
                                <div>
                                    <label className="block text-sm font-medium text-zinc-400 mb-1.5">Name <span className="text-red-500">*</span></label>
                                    <input
                                        type="text"
                                        required
                                        value={formState.name}
                                        onChange={e => setFormState({ ...formState, name: e.target.value })}
                                        className="w-full bg-zinc-950 border border-zinc-800 rounded-lg px-3 py-2 text-sm text-white focus:outline-none focus:border-teal-500 transition-colors"
                                    />
                                </div>
                                <div>
                                    <label className="block text-sm font-medium text-zinc-400 mb-1.5">Short Title (Optional)</label>
                                    <input
                                        type="text"
                                        value={formState.title_display_name}
                                        onChange={e => setFormState({ ...formState, title_display_name: e.target.value })}
                                        placeholder="e.g. Eng"
                                        className="w-full bg-zinc-950 border border-zinc-800 rounded-lg px-3 py-2 text-sm text-white focus:outline-none focus:border-teal-500 transition-colors"
                                    />
                                </div>
                                <div>
                                    <label className="block text-sm font-medium text-zinc-400 mb-1.5">Description (Optional)</label>
                                    <textarea
                                        rows={3}
                                        value={formState.description}
                                        onChange={e => setFormState({ ...formState, description: e.target.value })}
                                        className="w-full bg-zinc-950 border border-zinc-800 rounded-lg px-3 py-2 text-sm text-white focus:outline-none focus:border-teal-500 transition-colors resize-none"
                                    />
                                </div>
                                <div>
                                    <label className="block text-sm font-medium text-zinc-400 mb-1.5">Status</label>
                                    <select
                                        value={formState.status}
                                        onChange={e => setFormState({ ...formState, status: e.target.value })}
                                        className="w-full bg-zinc-950 border border-zinc-800 rounded-lg px-3 py-2 text-sm text-white focus:outline-none focus:border-teal-500 transition-colors"
                                    >
                                        <option value="ACTIVE">Active</option>
                                        <option value="INACTIVE">Inactive</option>
                                    </select>
                                </div>
                            </form>
                        </div>
                        <div className="p-4 border-t border-zinc-800 bg-zinc-900/50 flex justify-end gap-3">
                            <button
                                type="button"
                                onClick={() => setIsModalOpen(false)}
                                disabled={saving}
                                className="px-4 py-2 text-sm font-medium text-zinc-300 hover:text-white transition-colors"
                            >
                                Cancel
                            </button>
                            <button
                                type="submit"
                                form="deptForm"
                                disabled={saving}
                                className="bg-white text-black px-4 py-2 rounded-lg text-sm font-medium hover:bg-zinc-200 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
                            >
                                {saving ? (
                                    <><div className="w-4 h-4 border-2 border-black/20 border-t-black rounded-full animate-spin"/> Saving...</>
                                ) : (
                                    <><Check className="w-4 h-4" /> Save Record</>
                                )}
                            </button>
                        </div>
                    </div>
                </div>
            )}

            {mappingRecord && (
                <DesignationMappingModal 
                    subDepartment={mappingRecord}
                    departmentName={allDepartments.find(d => d.id === mappingRecord.department_id)?.name || 'Unknown'}
                    onClose={() => setMappingRecord(null)}
                />
            )}
        </div>
    )
}