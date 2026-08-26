'use client'

import { useState, useCallback } from 'react'
import { Plus, Edit2, CheckCircle2, XCircle, Search, MapPin } from 'lucide-react'
import { createPostalCode, updatePostalCode, setPostalMappings, getPostalCodes, getUnits } from '../actions'

const CATALOG_ADMIN_ROLES = ['PLATFORM_SUPERADMIN', 'CATALOG_MANAGER']

interface PostalMapping {
  geography_unit_id: string
  unit_name: string
  level_label: string
}

interface PostalCode {
  id: string
  country_id: string
  postal_code: string
  status: string
  created_at: string
  updated_at: string
  mappings: PostalMapping[]
}

interface Unit {
  id: string
  official_code: string
  display_name: string
  level_label: string
}

interface Props {
  initialPostalCodes: PostalCode[]
  initialTotal: number
  country: { id: string; display_name: string } | null
  staffRole: string
}

export function PostalCodesClient({ initialPostalCodes, initialTotal, country, staffRole }: Props) {
  const [postalCodes, setPostalCodes] = useState<PostalCode[]>(initialPostalCodes)
  const [total, setTotal] = useState(initialTotal)
  const [filterStatus, setFilterStatus] = useState('')
  const [search, setSearch] = useState('')
  const [loading, setLoading] = useState(false)
  const [isFormOpen, setIsFormOpen] = useState(false)
  const [isMappingOpen, setIsMappingOpen] = useState(false)
  const [activePostal, setActivePostal] = useState<PostalCode | null>(null)
  
  const [formData, setFormData] = useState({ id: '', postal_code: '', status: 'ACTIVE' })
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  // Mapping state
  const [unitSearch, setUnitSearch] = useState('')
  const [unitResults, setUnitResults] = useState<Unit[]>([])
  const [selectedUnits, setSelectedUnits] = useState<Unit[]>([])
  const [loadingUnits, setLoadingUnits] = useState(false)

  const canEdit = CATALOG_ADMIN_ROLES.includes(staffRole)

  const fetchPostalCodes = useCallback(async (opts?: { status?: string; search?: string }) => {
    if (!country) return
    setLoading(true)
    setError(null)
    try {
      const res = await getPostalCodes({
        country_id: country.id,
        status: opts?.status ?? (filterStatus || undefined),
        search: opts?.search ?? (search || undefined),
        limit: 100,
      })
      setPostalCodes(res.rows)
      setTotal(res.total)
    } catch (err: any) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }, [country, filterStatus, search])

  const applyFilters = () => fetchPostalCodes()

  const openCreate = () => {
    setFormData({ id: '', postal_code: '', status: 'ACTIVE' })
    setError(null)
    setIsFormOpen(true)
  }

  const openEdit = (item: PostalCode) => {
    setFormData({ id: item.id, postal_code: item.postal_code, status: item.status })
    setError(null)
    setIsFormOpen(true)
  }

  const openMapping = (item: PostalCode) => {
    setActivePostal(item)
    // Pre-fill selected units from mappings
    setSelectedUnits(item.mappings.map(m => ({
      id: m.geography_unit_id,
      official_code: '',
      display_name: m.unit_name,
      level_label: m.level_label
    })))
    setUnitSearch('')
    setUnitResults([])
    setError(null)
    setIsMappingOpen(true)
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!country) return
    setSaving(true)
    setError(null)
    try {
      if (formData.id) {
        const updated = await updatePostalCode(formData.id, { postal_code: formData.postal_code, status: formData.status })
        setPostalCodes(postalCodes.map(p => p.id === updated.id ? { ...p, ...updated } : p))
      } else {
        const created = await createPostalCode({ country_id: country.id, postal_code: formData.postal_code })
        setPostalCodes([...postalCodes, created])
        setTotal(total + 1)
      }
      setIsFormOpen(false)
    } catch (err: any) {
      setError(err.message)
    } finally {
      setSaving(false)
    }
  }

  const toggleStatus = async (item: PostalCode) => {
    if (!canEdit) return
    try {
      const updated = await updatePostalCode(item.id, {
        postal_code: item.postal_code,
        status: item.status === 'ACTIVE' ? 'INACTIVE' : 'ACTIVE',
      })
      setPostalCodes(postalCodes.map(p => p.id === updated.id ? { ...p, ...updated } : p))
    } catch (err: any) {
      setError(err.message)
    }
  }

  const searchUnits = async () => {
    if (!country || !unitSearch || unitSearch.length < 2) return
    setLoadingUnits(true)
    try {
      const res = await getUnits({ country_id: country.id, search: unitSearch, status: 'ACTIVE', limit: 20 })
      setUnitResults(res.rows)
    } catch (err) {
      console.error(err)
    } finally {
      setLoadingUnits(false)
    }
  }

  const toggleUnitSelection = (unit: Unit) => {
    if (selectedUnits.find(u => u.id === unit.id)) {
      setSelectedUnits(selectedUnits.filter(u => u.id !== unit.id))
    } else {
      setSelectedUnits([...selectedUnits, unit])
    }
  }

  const handleSaveMapping = async () => {
    if (!activePostal) return
    setSaving(true)
    setError(null)
    try {
      await setPostalMappings(activePostal.id, selectedUnits.map(u => u.id))
      // Update local state mappings
      const newMappings = selectedUnits.map(u => ({
        geography_unit_id: u.id,
        unit_name: u.display_name,
        level_label: u.level_label
      }))
      setPostalCodes(postalCodes.map(p => p.id === activePostal.id ? { ...p, mappings: newMappings } : p))
      setIsMappingOpen(false)
    } catch (err: any) {
      setError(err.message)
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="space-y-5 relative">
      {/* Filters */}
      <div className="flex flex-wrap items-center gap-3">
        <div className="relative flex-1 min-w-48">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-500" />
          <input
            value={search}
            onChange={e => setSearch(e.target.value)}
            onKeyDown={e => e.key === 'Enter' && fetchPostalCodes({ search: search })}
            placeholder="Search postal code…"
            className="w-full pl-9 pr-3 py-2 bg-zinc-900 border border-zinc-800 rounded-lg text-sm"
          />
        </div>
        <select
          value={filterStatus}
          onChange={e => { setFilterStatus(e.target.value); fetchPostalCodes({ status: e.target.value }) }}
          className="bg-zinc-900 border border-zinc-800 rounded-lg px-3 py-2 text-sm"
        >
          <option value="">All Statuses</option>
          <option value="ACTIVE">Active</option>
          <option value="INACTIVE">Inactive</option>
        </select>
        <button onClick={applyFilters} className="px-3 py-2 bg-zinc-800 hover:bg-zinc-700 rounded-lg text-sm font-medium transition-colors">
          Apply
        </button>
        {canEdit && (
          <button onClick={openCreate} className="ml-auto flex items-center gap-2 bg-teal-600 hover:bg-teal-700 text-white px-4 py-2 rounded-lg text-sm font-medium transition-colors">
            <Plus className="w-4 h-4" /> Add Postal Code
          </button>
        )}
      </div>

      <div className="text-xs text-zinc-500">
        Showing {postalCodes.length} of {total} postal codes
        {country && <> — Country: <span className="text-zinc-300">{country.display_name}</span></>}
      </div>

      {error && <div className="p-4 bg-red-900/50 border border-red-800 text-red-200 rounded-lg text-sm">{error}</div>}

      {/* Create/Edit Form */}
      {isFormOpen && (
        <form onSubmit={handleSubmit} className="p-6 bg-zinc-900/50 border border-zinc-800 rounded-xl space-y-4">
          <h3 className="font-semibold">{formData.id ? 'Edit Postal Code' : 'Add Postal Code'}</h3>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium mb-1">Postal Code</label>
              <input
                required
                value={formData.postal_code}
                onChange={e => setFormData({ ...formData, postal_code: e.target.value })}
                className="w-full bg-zinc-950 border border-zinc-800 rounded-lg px-3 py-2 font-mono"
                placeholder="e.g. 110001"
              />
            </div>
            {formData.id && (
              <div className="flex items-center gap-2 pt-6">
                <input
                  type="checkbox"
                  id="postalActive"
                  checked={formData.status === 'ACTIVE'}
                  onChange={e => setFormData({ ...formData, status: e.target.checked ? 'ACTIVE' : 'INACTIVE' })}
                  className="w-4 h-4 rounded"
                />
                <label htmlFor="postalActive" className="text-sm font-medium">Active</label>
              </div>
            )}
          </div>
          <div className="flex justify-end gap-2 pt-2">
            <button type="button" onClick={() => setIsFormOpen(false)} className="px-4 py-2 hover:bg-zinc-800 rounded-lg text-sm font-medium">Cancel</button>
            <button type="submit" disabled={saving} className="px-4 py-2 bg-teal-600 hover:bg-teal-700 text-white rounded-lg text-sm font-medium disabled:opacity-50">
              {saving ? 'Saving…' : 'Save'}
            </button>
          </div>
        </form>
      )}

      {/* Mapping Modal */}
      {isMappingOpen && activePostal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
          <div className="bg-zinc-900 border border-zinc-800 rounded-xl w-full max-w-2xl max-h-[90vh] flex flex-col shadow-2xl">
            <div className="p-6 border-b border-zinc-800">
              <h2 className="text-xl font-bold">Map Geography Units</h2>
              <p className="text-zinc-400 text-sm mt-1">Assign units for postal code <span className="font-mono text-white">{activePostal.postal_code}</span></p>
            </div>
            
            <div className="p-6 overflow-y-auto flex-1 space-y-6">
              <div>
                <label className="block text-sm font-medium mb-2">Search Units</label>
                <div className="flex gap-2">
                  <input
                    value={unitSearch}
                    onChange={e => setUnitSearch(e.target.value)}
                    onKeyDown={e => e.key === 'Enter' && searchUnits()}
                    placeholder="Enter unit name or code..."
                    className="flex-1 bg-zinc-950 border border-zinc-800 rounded-lg px-3 py-2 text-sm"
                  />
                  <button type="button" onClick={searchUnits} className="px-4 py-2 bg-zinc-800 hover:bg-zinc-700 rounded-lg text-sm font-medium">
                    {loadingUnits ? '...' : 'Search'}
                  </button>
                </div>
              </div>

              {unitResults.length > 0 && (
                <div className="border border-zinc-800 rounded-lg overflow-hidden bg-zinc-950/50">
                  <div className="max-h-48 overflow-y-auto">
                    {unitResults.map(u => (
                      <label key={u.id} className="flex items-center gap-3 p-3 hover:bg-zinc-800/50 border-b border-zinc-800 last:border-0 cursor-pointer">
                        <input
                          type="checkbox"
                          checked={!!selectedUnits.find(s => s.id === u.id)}
                          onChange={() => toggleUnitSelection(u)}
                          className="w-4 h-4 rounded"
                        />
                        <div>
                          <div className="font-medium">{u.display_name}</div>
                          <div className="text-xs text-zinc-500">{u.level_label} • {u.official_code}</div>
                        </div>
                      </label>
                    ))}
                  </div>
                </div>
              )}

              <div>
                <h4 className="text-sm font-medium mb-3">Selected Units ({selectedUnits.length})</h4>
                {selectedUnits.length === 0 ? (
                  <div className="text-sm text-zinc-500 italic p-4 text-center border border-dashed border-zinc-800 rounded-lg">No units mapped yet.</div>
                ) : (
                  <div className="flex flex-wrap gap-2">
                    {selectedUnits.map(u => (
                      <div key={u.id} className="flex items-center gap-2 bg-zinc-800 border border-zinc-700 pl-3 pr-2 py-1.5 rounded-lg text-sm">
                        <span>{u.display_name} <span className="text-zinc-500 text-xs ml-1">({u.level_label})</span></span>
                        <button type="button" onClick={() => toggleUnitSelection(u)} className="text-zinc-500 hover:text-white p-0.5 rounded-md hover:bg-zinc-700">
                          <XCircle className="w-3.5 h-3.5" />
                        </button>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>

            <div className="p-6 border-t border-zinc-800 bg-zinc-900/50 flex justify-end gap-3 rounded-b-xl">
              <button type="button" onClick={() => setIsMappingOpen(false)} className="px-4 py-2 hover:bg-zinc-800 rounded-lg text-sm font-medium">
                Cancel
              </button>
              <button type="button" onClick={handleSaveMapping} disabled={saving} className="px-6 py-2 bg-teal-600 hover:bg-teal-700 text-white rounded-lg text-sm font-medium disabled:opacity-50">
                {saving ? 'Saving…' : 'Save Mappings'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Table */}
      {loading ? (
        <div className="py-12 text-center text-zinc-500 animate-pulse">Loading postal codes…</div>
      ) : (
        <div className="border border-zinc-800 rounded-xl overflow-hidden bg-zinc-900/30">
          <table className="w-full text-left text-sm">
            <thead className="bg-zinc-900/80 border-b border-zinc-800 text-zinc-400">
              <tr>
                <th className="px-4 py-3 font-medium">Postal Code</th>
                <th className="px-4 py-3 font-medium">Mapped Units</th>
                <th className="px-4 py-3 font-medium">Status</th>
                {canEdit && <th className="px-4 py-3 font-medium text-right">Actions</th>}
              </tr>
            </thead>
            <tbody className="divide-y divide-zinc-800/50">
              {postalCodes.length === 0 ? (
                <tr><td colSpan={4} className="px-6 py-12 text-center text-zinc-500">
                  <div className="max-w-xs mx-auto">
                    <MapPin className="w-8 h-8 mx-auto mb-3 text-zinc-600" />
                    <p>No postal codes found.</p>
                    <p className="text-xs mt-1">Add valid postal codes and map them to their corresponding geography units.</p>
                  </div>
                </td></tr>
              ) : postalCodes.map(item => (
                <tr key={item.id} className="hover:bg-zinc-800/30 transition-colors">
                  <td className="px-4 py-3 font-mono font-medium text-zinc-200">{item.postal_code}</td>
                  <td className="px-4 py-3">
                    {item.mappings.length === 0 ? (
                      <span className="text-zinc-600 text-xs italic">Unmapped</span>
                    ) : (
                      <div className="flex flex-wrap gap-1.5">
                        {item.mappings.slice(0, 3).map(m => (
                          <span key={m.geography_unit_id} className="inline-flex text-[11px] bg-zinc-800 text-zinc-300 px-2 py-0.5 rounded-full border border-zinc-700">
                            {m.unit_name}
                          </span>
                        ))}
                        {item.mappings.length > 3 && (
                          <span className="inline-flex text-[11px] bg-zinc-900 text-zinc-500 px-2 py-0.5 rounded-full border border-zinc-800">
                            +{item.mappings.length - 3} more
                          </span>
                        )}
                      </div>
                    )}
                  </td>
                  <td className="px-4 py-3">
                    {item.status === 'ACTIVE'
                      ? <span className="inline-flex items-center gap-1 text-emerald-400 text-xs font-medium"><CheckCircle2 className="w-3 h-3" /> Active</span>
                      : <span className="inline-flex items-center gap-1 text-red-400 text-xs font-medium"><XCircle className="w-3 h-3" /> Inactive</span>
                    }
                  </td>
                  {canEdit && (
                    <td className="px-4 py-3 text-right flex items-center justify-end gap-2">
                      <button onClick={() => openMapping(item)} className="text-xs px-2 py-1.5 rounded font-medium bg-zinc-800 hover:bg-zinc-700 transition-colors text-zinc-300">
                        Map Units
                      </button>
                      <button onClick={() => openEdit(item)} className="p-1.5 text-zinc-400 hover:text-white rounded hover:bg-zinc-700 transition-colors" title="Edit Postal Code">
                        <Edit2 className="w-4 h-4" />
                      </button>
                      <button
                        onClick={() => toggleStatus(item)}
                        className={`text-xs px-2 py-1.5 rounded font-medium transition-colors ${item.status === 'ACTIVE' ? 'text-red-400 hover:bg-red-900/30' : 'text-emerald-400 hover:bg-emerald-900/30'}`}
                      >
                        {item.status === 'ACTIVE' ? 'Inactivate' : 'Activate'}
                      </button>
                    </td>
                  )}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
