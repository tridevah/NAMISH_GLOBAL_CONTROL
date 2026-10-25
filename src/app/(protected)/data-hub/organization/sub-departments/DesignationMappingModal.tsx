import { useState, useEffect, useRef, useCallback } from 'react'
import { X, Search, AlertCircle, RefreshCw } from 'lucide-react'

interface DesignationMappingModalProps {
    subDepartment: any;
    departmentName: string;
    onClose: () => void;
}

export function DesignationMappingModal({ subDepartment, departmentName, onClose }: DesignationMappingModalProps) {
    const [allDesignations, setAllDesignations] = useState<any[]>([])
    const [mappings, setMappings] = useState<any[]>([])
    const [parentMappings, setParentMappings] = useState<any[]>([])
    const [search, setSearch] = useState('')
    
    // Lifecycle states
    const [initialLoading, setInitialLoading] = useState(true)
    const [parentLoading, setParentLoading] = useState(false)
    const [refreshing, setRefreshing] = useState(false)
    
    // Error states
    const [initialError, setInitialError] = useState('')
    const [parentError, setParentError] = useState(false)
    const [saveError, setSaveError] = useState('')
    const [refreshError, setRefreshError] = useState(false)
    
    const [saving, setSaving] = useState(false)
    
    // Deltas
    const [addIds, setAddIds] = useState<Set<string>>(new Set())
    const [removeIds, setRemoveIds] = useState<Set<string>>(new Set())

    const initAbortRef = useRef<AbortController | null>(null)
    const parentAbortRef = useRef<AbortController | null>(null)
    const refreshAbortRef = useRef<AbortController | null>(null)
    
    // Generation guard to prevent stale background refreshes from overwriting newer saved baselines
    const baselineGenerationRef = useRef<number>(0)

    const fetchAllDesignations = async (signal: AbortSignal) => {
        let all: any[] = [];
        let page = 1;
        let limit = 50;
        let hasMore = true;
        
        while (hasMore) {
            const res = await fetch(`/api/data-hub/organization/designations?page=${page}&limit=${limit}`, { signal })
            if (!res.ok) {
                const data = await res.json().catch(() => ({}))
                throw new Error(data.error || 'Failed to fetch designations')
            }
            const data = await res.json()
            const items = data.data
            if (!Array.isArray(items)) throw new Error('Invalid designations data')
            all = [...all, ...items]
            if (items.length < limit) {
                hasMore = false
            } else {
                page++
            }
        }
        return all;
    }

    const fetchInitialData = useCallback(async () => {
        if (initAbortRef.current) initAbortRef.current.abort()
        const abortController = new AbortController()
        initAbortRef.current = abortController
        const signal = abortController.signal

        setInitialLoading(true)
        setInitialError('')
        setParentError(false)

        try {
            const [desigData, mapRes] = await Promise.all([
                fetchAllDesignations(signal),
                fetch(`/api/data-hub/organization/sub-departments/${subDepartment.id}/designations`, { signal })
            ])

            if (!mapRes.ok) {
                const md = await mapRes.json().catch(() => ({}))
                throw new Error(md.error || 'Failed to fetch mappings')
            }
            
            const md = await mapRes.json()
            if (!Array.isArray(md.data)) throw new Error('Invalid mapping data')

            if (!signal.aborted) {
                setAllDesignations(desigData)
                setMappings(md.data)
                setAddIds(new Set())
                setRemoveIds(new Set())
                baselineGenerationRef.current += 1
            }
            
            await fetchParentEligibility(signal)

        } catch (e: any) {
            if (!signal.aborted && e.name !== 'AbortError') setInitialError(e.message || 'Error loading designations data')
        } finally {
            if (!signal.aborted) setInitialLoading(false)
        }
    }, [subDepartment.id])

    const fetchParentEligibility = async (signalOverride?: AbortSignal) => {
        if (!subDepartment.department_id) {
            setParentMappings([])
            return
        }

        if (parentAbortRef.current) parentAbortRef.current.abort()
        const abortController = new AbortController()
        parentAbortRef.current = abortController
        const signal = signalOverride || abortController.signal

        setParentError(false)
        if (!signalOverride) setParentLoading(true)

        try {
            const pRes = await fetch(`/api/data-hub/organization/departments/${subDepartment.department_id}/designations`, { signal })
            if (!pRes.ok) throw new Error('Parent eligibility fetch failed')
            
            const pData = await pRes.json()
            if (!Array.isArray(pData.data)) throw new Error('Invalid parent mapping data')

            if (!signal.aborted) {
                setParentMappings(pData.data)
            }
        } catch (e: any) {
            if (!signal.aborted && e.name !== 'AbortError') {
                setParentError(true)
            }
        } finally {
            if (!signal.aborted && !signalOverride) setParentLoading(false)
        }
    }

    const refreshMappings = async () => {
        if (refreshAbortRef.current) refreshAbortRef.current.abort()
        const abortController = new AbortController()
        refreshAbortRef.current = abortController
        const signal = abortController.signal
        
        const expectedGeneration = baselineGenerationRef.current

        setRefreshing(true)
        try {
            const mapRes = await fetch(`/api/data-hub/organization/sub-departments/${subDepartment.id}/designations`, { signal })
            if (!mapRes.ok) throw new Error('Failed to refresh mappings')
            
            const mapData = await mapRes.json()
            if (!Array.isArray(mapData.data)) throw new Error('Invalid mapping data')
            
            if (!signal.aborted) {
                if (baselineGenerationRef.current === expectedGeneration) {
                    setMappings(mapData.data)
                    setRefreshError(false)
                }
            }
        } catch (e: any) {
            if (!signal.aborted && e.name !== 'AbortError') {
                setRefreshError(true)
            }
        } finally {
            if (!signal.aborted) setRefreshing(false)
        }
    }

    useEffect(() => {
        fetchInitialData()
        return () => {
            if (initAbortRef.current) initAbortRef.current.abort()
            if (parentAbortRef.current) parentAbortRef.current.abort()
            if (refreshAbortRef.current) refreshAbortRef.current.abort()
        }
    }, [fetchInitialData])

    const isCurrentlyMapped = (designationId: string) => {
        const existing = mappings.find(m => m.designation_id === designationId)
        return existing && existing.status === 'ACTIVE'
    }

    const isParentEligible = (designationId: string) => {
        const existing = parentMappings.find(m => m.designation_id === designationId)
        return existing && existing.status === 'ACTIVE'
    }

    const isChecked = (designationId: string) => {
        if (addIds.has(designationId)) return true
        if (removeIds.has(designationId)) return false
        return isCurrentlyMapped(designationId)
    }

    const isToggleAllowed = (desig: any) => {
        if (saving || initialLoading) return false;

        const currentlyChecked = isChecked(desig.id);
        const currentlyMapped = isCurrentlyMapped(desig.id);
        const parentEligible = isParentEligible(desig.id);
        const isParentReady = !parentLoading && !parentError;

        const willBeChecked = !currentlyChecked;

        if (willBeChecked) {
            if (currentlyMapped) {
                return true; // Canceling a known removal. Always allowed.
            } else {
                if (!isParentReady || !parentEligible || subDepartment.status !== 'ACTIVE' || desig.status !== 'ACTIVE') {
                    return false; // Block addition
                }
                return true;
            }
        } else {
            return true; // Attempting to uncheck (remove or cancel addition). Always allowed.
        }
    }

    const toggleDesignation = (desig: any) => {
        if (!isToggleAllowed(desig)) return;

        const currentlyMapped = isCurrentlyMapped(desig.id)
        const id = desig.id

        setAddIds(prev => {
            const next = new Set(prev)
            if (currentlyMapped) return next
            if (next.has(id)) next.delete(id)
            else next.add(id)
            return next
        })

        setRemoveIds(prev => {
            const next = new Set(prev)
            if (!currentlyMapped) return next
            if (next.has(id)) next.delete(id)
            else next.add(id)
            return next
        })
    }

    const isParentReady = !parentLoading && !parentError;
    const hasPendingAdditions = addIds.size > 0;
    const noChanges = addIds.size === 0 && removeIds.size === 0;
    
    // Save is blocked if there are pending additions BUT parent eligibility is unknown/loading
    const isSaveBlocked = saving || noChanges || (hasPendingAdditions && !isParentReady);

    const handleSave = async () => {
        if (noChanges) {
            onClose();
            return;
        }

        // Enforcement of block rule in handleSave
        if (isSaveBlocked) return;

        setSaving(true)
        setSaveError('')
        
        const submittedAdd = Array.from(addIds)
        const submittedRemove = Array.from(removeIds)

        try {
            const res = await fetch(`/api/data-hub/organization/sub-departments/${subDepartment.id}/designations`, {
                method: 'PATCH',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    add_ids: submittedAdd,
                    remove_ids: submittedRemove
                })
            })
            
            const data = await res.json().catch(() => ({}))
            if (!res.ok) throw new Error(data.error || 'Failed to save mappings')
            
            setMappings(prev => {
                const next = prev.map(m => ({ ...m }))
                submittedAdd.forEach(id => {
                    const idx = next.findIndex(m => m.designation_id === id)
                    if (idx >= 0) next[idx].status = 'ACTIVE'
                    else next.push({ sub_department_id: subDepartment.id, designation_id: id, status: 'ACTIVE' })
                })
                submittedRemove.forEach(id => {
                    const idx = next.findIndex(m => m.designation_id === id)
                    if (idx >= 0) next[idx].status = 'INACTIVE'
                })
                return next
            })
            
            baselineGenerationRef.current += 1
            
            setAddIds(prev => {
                const next = new Set(prev)
                submittedAdd.forEach(id => next.delete(id))
                return next
            })
            setRemoveIds(prev => {
                const next = new Set(prev)
                submittedRemove.forEach(id => next.delete(id))
                return next
            })

            refreshMappings()
            
        } catch (e: any) {
            setSaveError(e.message || 'Error saving mappings')
        } finally {
            setSaving(false)
        }
    }

    const filteredDesignations = allDesignations.filter(d => {
        const matchesSearch = d.name.toLowerCase().includes(search.toLowerCase()) || d.code.toLowerCase().includes(search.toLowerCase())
        if (matchesSearch) return true
        return false
    })

    const displayList = search ? filteredDesignations : allDesignations
    const unknownMappedItems = mappings.filter(m => !allDesignations.some(d => d.id === m.designation_id))
    
    return (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
            <div className="bg-[#111] border border-zinc-800 rounded-xl w-full max-w-2xl flex flex-col shadow-2xl max-h-[90vh]">
                <div className="flex-none p-6 border-b border-zinc-800 flex justify-between items-start">
                    <div>
                        <h2 className="text-lg font-semibold text-white">Manage Designations</h2>
                        <p className="text-zinc-400 text-sm mt-1">
                            {departmentName} &rsaquo; <span className="text-zinc-200 font-medium">{subDepartment.name}</span>
                        </p>
                    </div>
                    <button onClick={onClose} disabled={saving} className="text-zinc-500 hover:text-white transition-colors disabled:opacity-50">
                        <X className="w-5 h-5" />
                    </button>
                </div>

                <div className="flex-1 overflow-hidden flex flex-col">
                    <div className="p-4 border-b border-zinc-800">
                        <div className="relative">
                            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-500" />
                            <input
                                type="text"
                                placeholder="Search designations..."
                                value={search}
                                onChange={(e) => setSearch(e.target.value)}
                                className="w-full bg-zinc-900 border border-zinc-800 rounded-lg pl-10 pr-4 py-2 text-sm text-white focus:outline-none focus:border-teal-500 transition-colors"
                            />
                        </div>
                    </div>

                    <div className="flex-1 overflow-y-auto p-4">
                        {initialError && (
                            <div className="mb-4 p-3 bg-red-500/10 border border-red-500/20 rounded-lg flex items-start gap-3">
                                <AlertCircle className="w-5 h-5 text-red-400 flex-shrink-0 mt-0.5" />
                                <p className="text-sm text-red-400">{initialError}</p>
                            </div>
                        )}
                        {saveError && (
                            <div className="mb-4 p-3 bg-red-500/10 border border-red-500/20 rounded-lg flex items-start gap-3">
                                <AlertCircle className="w-5 h-5 text-red-400 flex-shrink-0 mt-0.5" />
                                <p className="text-sm text-red-400">{saveError}</p>
                            </div>
                        )}
                        {parentError && (
                            <div className="mb-4 p-3 bg-red-500/10 border border-red-500/20 rounded-lg flex items-start gap-3">
                                <AlertCircle className="w-5 h-5 text-red-400 flex-shrink-0 mt-0.5" />
                                <div className="text-sm text-red-400 flex-1 flex items-center justify-between">
                                    Unknown parent eligibility. Additions are blocked.
                                    <button onClick={() => fetchParentEligibility()} disabled={parentLoading} className="underline hover:text-red-300 disabled:opacity-50">
                                        {parentLoading ? 'Retrying...' : 'Retry'}
                                    </button>
                                </div>
                            </div>
                        )}
                        {parentLoading && !parentError && (
                            <div className="mb-4 p-3 bg-blue-500/10 border border-blue-500/20 rounded-lg flex items-start gap-3">
                                <RefreshCw className="w-5 h-5 text-blue-400 flex-shrink-0 mt-0.5 animate-spin" />
                                <p className="text-sm text-blue-400">Verifying parent eligibility...</p>
                            </div>
                        )}
                        {refreshError && (
                            <div className="mb-4 p-3 bg-amber-500/10 border border-amber-500/20 rounded-lg flex items-start gap-3">
                                <AlertCircle className="w-5 h-5 text-amber-400 flex-shrink-0 mt-0.5" />
                                <div className="text-sm text-amber-400 flex-1 flex items-center justify-between">
                                    Saved successfully; background refresh failed.
                                    <button onClick={refreshMappings} disabled={refreshing} className="underline hover:text-amber-300 disabled:opacity-50">
                                        {refreshing ? 'Refreshing...' : 'Retry Refresh'}
                                    </button>
                                </div>
                            </div>
                        )}

                        {initialLoading ? (
                            <div className="flex items-center justify-center py-12">
                                <RefreshCw className="w-6 h-6 text-zinc-500 animate-spin" />
                            </div>
                        ) : displayList.length === 0 && unknownMappedItems.length === 0 ? (
                            <div className="text-center py-12 text-zinc-500 text-sm">
                                No designations found.
                            </div>
                        ) : (
                            <div className="space-y-2">
                                {displayList.map(desig => {
                                    const currentlyChecked = isChecked(desig.id)
                                    const disabled = !isToggleAllowed(desig);
                                    
                                    const originalMapped = mappings.find(m => m.designation_id === desig.id)
                                    const hasInactiveHistory = originalMapped && originalMapped.status === 'INACTIVE'
                                    const parentEligible = isParentEligible(desig.id)
                                    
                                    let warningMsg = '';
                                    if (currentlyChecked && !parentEligible && isParentReady) {
                                        warningMsg = 'Ineligible: Not mapped to Parent Department (Cleanup recommended)';
                                    }
                                    
                                    return (
                                        <label 
                                            key={desig.id} 
                                            className={`flex items-start gap-3 p-3 rounded-lg border transition-colors ${disabled ? '' : 'cursor-pointer'} ${
                                                currentlyChecked ? 'bg-teal-500/5 border-teal-500/30' : 'bg-zinc-900/30 border-zinc-800 hover:bg-zinc-800/50'
                                            } ${disabled ? 'opacity-50' : ''}`}
                                        >
                                            <input
                                                type="checkbox"
                                                checked={currentlyChecked}
                                                disabled={disabled}
                                                onChange={() => toggleDesignation(desig)}
                                                className="mt-1 bg-zinc-900 border-zinc-700 text-teal-500 rounded focus:ring-teal-500 focus:ring-offset-zinc-900 disabled:cursor-not-allowed"
                                            />
                                            <div className="flex-1">
                                                <div className="flex items-center gap-2">
                                                    <span className="font-medium text-white">{desig.name}</span>
                                                    <span className="text-xs text-zinc-500 px-1.5 py-0.5 rounded bg-zinc-800">{desig.code}</span>
                                                    {desig.status === 'INACTIVE' && (
                                                        <span className="text-xs text-red-400">Inactive</span>
                                                    )}
                                                </div>
                                                {warningMsg && (
                                                    <p className="text-xs text-amber-500 mt-1">{warningMsg}</p>
                                                )}
                                                {hasInactiveHistory && !currentlyChecked && !warningMsg && (
                                                    <p className="text-xs text-zinc-500 mt-1">Has inactive mapping history</p>
                                                )}
                                                {!parentEligible && !currentlyChecked && !warningMsg && isParentReady && (
                                                    <p className="text-xs text-zinc-500 mt-1">Not mapped to parent department</p>
                                                )}
                                            </div>
                                        </label>
                                    )
                                })}

                                {unknownMappedItems.map(m => {
                                    const desigStub = { id: m.designation_id, status: 'UNKNOWN' };
                                    const currentlyChecked = isChecked(m.designation_id)
                                    const disabled = !isToggleAllowed(desigStub);
                                    const isInactiveHistory = m.status === 'INACTIVE'
                                    
                                    return (
                                        <label 
                                            key={m.designation_id} 
                                            className={`flex items-start gap-3 p-3 rounded-lg border transition-colors ${disabled ? '' : 'cursor-pointer'} ${
                                                currentlyChecked ? 'bg-teal-500/5 border-teal-500/30' : 'bg-zinc-900/30 border-zinc-800 hover:bg-zinc-800/50'
                                            } ${disabled ? 'opacity-50' : ''}`}
                                        >
                                            <input
                                                type="checkbox"
                                                checked={currentlyChecked}
                                                disabled={disabled}
                                                onChange={() => toggleDesignation(desigStub)}
                                                className="mt-1 bg-zinc-900 border-zinc-700 text-teal-500 rounded focus:ring-teal-500 focus:ring-offset-zinc-900 disabled:cursor-not-allowed"
                                            />
                                            <div className="flex-1">
                                                <div className="flex items-center gap-2">
                                                    <span className="font-medium text-white italic">Unknown Designation</span>
                                                    <span className="text-xs text-zinc-500 px-1.5 py-0.5 rounded bg-zinc-800">
                                                        {m.designation_id.split('-')[0]}...
                                                    </span>
                                                </div>
                                                <p className="text-xs text-amber-500 mt-1">Not loaded in global list (Cleanup recommended)</p>
                                                {isInactiveHistory && !currentlyChecked && (
                                                    <p className="text-xs text-zinc-500 mt-1">Has inactive mapping history</p>
                                                )}
                                            </div>
                                        </label>
                                    )
                                })}
                            </div>
                        )}
                    </div>
                </div>

                <div className="flex-none p-4 border-t border-zinc-800 flex justify-end gap-3 bg-[#111]">
                    <button
                        onClick={onClose}
                        disabled={saving}
                        className="px-4 py-2 text-sm font-medium text-white hover:bg-zinc-800 rounded-lg transition-colors disabled:opacity-50"
                    >
                        Close
                    </button>
                    <button
                        onClick={handleSave}
                        disabled={isSaveBlocked}
                        className="px-4 py-2 text-sm font-medium bg-white text-black hover:bg-zinc-200 rounded-lg transition-colors disabled:opacity-50 flex items-center gap-2"
                    >
                        {saving && <RefreshCw className="w-4 h-4 animate-spin" />}
                        Save Changes
                    </button>
                </div>
            </div>
        </div>
    )
}