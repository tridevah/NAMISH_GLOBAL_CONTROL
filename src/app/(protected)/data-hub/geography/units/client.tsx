'use client'

import { useState, useCallback } from 'react'
import { Plus, Edit2, CheckCircle2, XCircle, Search, ChevronRight } from 'lucide-react'
import { createUnit, updateUnit, getUnits } from '../actions'

const CATALOG_ADMIN_ROLES = ['PLATFORM_SUPERADMIN', 'CATALOG_MANAGER']

interface Unit {
  id: string
  country_id: string
  geography_level_id: string
  level_number: number
  level_key: string
  level_label: string
  parent_geography_unit_id: string | null
  parent_name: string | null
  official_code: string
  iso_subdivision_code: string | null
  official_name: string
  display_name: string
  status: string
}

interface Level {
  id: string
  level_number: number
  level_key: string
  display_label: string
  status: string
}

interface Props {
  initialUnits: Unit[]
  initialTotal: number
  country: { id: string; display_name: string } | null
  levels: Level[]
  staffRole: string
}

const emptyForm = {
  id: '', geography_level_id: '', parent_geography_unit_id: '',
  official_code: '', iso_subdivision_code: '', official_name: '', display_name: '', status: 'ACTIVE',
}

export function UnitsClient({ initialUnits, initialTotal, country, levels, staffRole }: Props) {
  const [units, setUnits] = useState<Unit[]>(initialUnits)
  const [total, setTotal] = useState(initialTotal)
  const [filterLevel, setFilterLevel] = useState('')
  const [filterStatus, setFilterStatus] = useState('')
  const [search, setSearch] = useState('')
  const [loading, setLoading] = useState(false)
  const [isFormOpen, setIsFormOpen] = useState(false)
  const [formData, setFormData] = useState({ ...emptyForm })
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [parentOptions, setParentOptions] = useState<Unit[]>([])
  const [loadingParents, setLoadingParents] = useState(false)

  const canEdit = CATALOG_ADMIN_ROLES.includes(staffRole)

  const fetchUnits = useCallback(async (opts?: {
    level_id?: string; status?: string; search?: string
  }) => {
    if (!country) return
    setLoading(true)
    setError(null)
    try {
      const res = await getUnits({
        country_id: country.id,
        level_id: opts?.level_id ?? (filterLevel || undefined),
        status: opts?.status ?? (filterStatus || undefined),
        search: opts?.search ?? (search || undefined),
        limit: 200,
      })
      setUnits(res.rows)
      setTotal(res.total)
    } catch (err: any) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }, [country, filterLevel, filterStatus, search])

  const applyFilters = () => fetchUnits()

  const openCreate = async () => {
    setFormData({ ...emptyForm })
    setParentOptions([])
    setError(null)
    setIsFormOpen(true)
  }

  const openEdit = (item: Unit) => {
    setFormData({
      id: item.id,
      geography_level_id: item.geography_level_id,
      parent_geography_unit_id: item.parent_geography_unit_id ?? '',
      official_code: item.official_code,
      iso_subdivision_code: item.iso_subdivision_code ?? '',
      official_name: item.official_name,
      display_name: item.display_name,
      status: item.status,
    })
    setError(null)
    setIsFormOpen(true)
  }

  const onLevelChange = async (levelId: string) => {
    setFormData(f => ({ ...f, geography_level_id: levelId, parent_geography_unit_id: '' }))
    if (!country || !levelId) { setParentOptions([]); return }

    const selectedLevel = levels.find(l => l.id === levelId)
    if (!selectedLevel || selectedLevel.level_number <= 1) { setParentOptions([]); return }

    // Load parent candidates from previous level
    const prevLevel = levels.find(l => l.level_number === selectedLevel.level_number - 1)
    if (!prevLevel) { setParentOptions([]); return }

    setLoadingParents(true)
    try {
      const res = await getUnits({ country_id: country.id, level_id: prevLevel.id, status: 'ACTIVE', limit: 500 })
      setParentOptions(res.rows)
    } catch {
      setParentOptions([])
    } finally {
      setLoadingParents(false)
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!country) return
    setSaving(true)
    setError(null)
    try {
      if (formData.id) {
        const updated = await updateUnit(formData.id, {
          official_name: formData.official_name,
          display_name: formData.display_name,
          iso_subdivision_code: formData.iso_subdivision_code,
          status: formData.status,
        })
        setUnits(units.map(u => u.id === updated.id ? { ...u, ...updated } : u))
      } else {
        const created = await createUnit({
          country_id: country.id,
          geography_level_id: formData.geography_level_id,
          parent_geography_unit_id: formData.parent_geography_unit_id || undefined,
          official_code: formData.official_code,
          iso_subdivision_code: formData.iso_subdivision_code,
          official_name: formData.official_name,
          display_name: formData.display_name,
        })
        setUnits([...units, created])
        setTotal(total + 1)
      }
      setIsFormOpen(false)
    } catch (err: any) {
      setError(err.message)
    } finally {
      setSaving(false)
    }
  }

  const toggleStatus = async (item: Unit) => {
    if (!canEdit) return
    try {
      const updated = await updateUnit(item.id, {
        official_name: item.official_name,
        display_name: item.display_name,
        iso_subdivision_code: item.iso_subdivision_code ?? '',
        status: item.status === 'ACTIVE' ? 'INACTIVE' : 'ACTIVE',
      })
      setUnits(units.map(u => u.id === updated.id ? { ...u, ...updated } : u))
    } catch (err: any) {
      setError(err.message)
    }
  }

  const selectedLevel = levels.find(l => l.id === formData.geography_level_id)
  const needsParent = selectedLevel && selectedLevel.level_number > 1

  return (
    <div className="space-y-5">
      {/* Filter bar */}
      <div className="flex flex-wrap items-center gap-3">
        <div className="relative flex-1 min-w-48">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-500" />
          <input
            value={search}
            onChange={e => setSearch(e.target.value)}
            onKeyDown={e => e.key === 'Enter' && fetchUnits({ search: search })}
            placeholder="Search by name or code…"
            className="w-full pl-9 pr-3 py-2 bg-zinc-900 border border-zinc-800 rounded-lg text-sm"
          />
        </div>
        <select
          value={filterLevel}
          onChange={e => { setFilterLevel(e.target.value); fetchUnits({ level_id: e.target.value }) }}
          className="bg-zinc-900 border border-zinc-800 rounded-lg px-3 py-2 text-sm"
        >
          <option value="">All Levels</option>
          {levels.map(l => <option key={l.id} value={l.id}>{l.level_number}. {l.display_label}</option>)}
        </select>
        <select
          value={filterStatus}
          onChange={e => { setFilterStatus(e.target.value); fetchUnits({ status: e.target.value }) }}
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
            <Plus className="w-4 h-4" /> Add Unit
          </button>
        )}
      </div>

      <div className="text-xs text-zinc-500">
        Showing {units.length} of {total} units
        {country && <> — Country: <span className="text-zinc-300">{country.display_name}</span></>}
      </div>

      {error && <div className="p-4 bg-red-900/50 border border-red-800 text-red-200 rounded-lg text-sm">{error}</div>}

      {/* Create/Edit Form */}
      {isFormOpen && (
        <form onSubmit={handleSubmit} className="p-6 bg-zinc-900/50 border border-zinc-800 rounded-xl space-y-4">
          <h3 className="font-semibold">{formData.id ? 'Edit Unit' : 'Add Unit'}</h3>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium mb-1">Level</label>
              <select
                required
                disabled={!!formData.id}
                value={formData.geography_level_id}
                onChange={e => onLevelChange(e.target.value)}
                className="w-full bg-zinc-950 border border-zinc-800 rounded-lg px-3 py-2 disabled:opacity-50"
              >
                <option value="">Select level…</option>
                {levels.filter(l => l.status === 'ACTIVE').map(l => (
                  <option key={l.id} value={l.id}>{l.level_number}. {l.display_label}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="block text-sm font-medium mb-1">Official Code</label>
              <input
                required
                disabled={!!formData.id}
                value={formData.official_code}
                onChange={e => setFormData(f => ({ ...f, official_code: e.target.value }))}
                className="w-full bg-zinc-950 border border-zinc-800 rounded-lg px-3 py-2 font-mono disabled:opacity-50"
                placeholder="e.g. 27"
              />
            </div>
            {needsParent && (
              <div className="col-span-2">
                <label className="block text-sm font-medium mb-1">
                  Parent Unit <span className="text-zinc-500 font-normal">({selectedLevel.level_number - 1}. {levels.find(l => l.level_number === selectedLevel.level_number - 1)?.display_label})</span>
                </label>
                <select
                  required
                  disabled={!!formData.id || loadingParents}
                  value={formData.parent_geography_unit_id}
                  onChange={e => setFormData(f => ({ ...f, parent_geography_unit_id: e.target.value }))}
                  className="w-full bg-zinc-950 border border-zinc-800 rounded-lg px-3 py-2 disabled:opacity-50"
                >
                  <option value="">{loadingParents ? 'Loading…' : 'Select parent…'}</option>
                  {parentOptions.map(p => <option key={p.id} value={p.id}>{p.official_code} – {p.display_name}</option>)}
                </select>
              </div>
            )}
            <div>
              <label className="block text-sm font-medium mb-1">Official Name</label>
              <input
                required
                value={formData.official_name}
                onChange={e => setFormData(f => ({ ...f, official_name: e.target.value }))}
                className="w-full bg-zinc-950 border border-zinc-800 rounded-lg px-3 py-2"
              />
            </div>
            <div>
              <label className="block text-sm font-medium mb-1">Display Name</label>
              <input
                required
                value={formData.display_name}
                onChange={e => setFormData(f => ({ ...f, display_name: e.target.value }))}
                className="w-full bg-zinc-950 border border-zinc-800 rounded-lg px-3 py-2"
              />
            </div>
            <div>
              <label className="block text-sm font-medium mb-1">ISO Subdivision Code <span className="text-zinc-500">(optional)</span></label>
              <input
                value={formData.iso_subdivision_code}
                onChange={e => setFormData(f => ({ ...f, iso_subdivision_code: e.target.value }))}
                className="w-full bg-zinc-950 border border-zinc-800 rounded-lg px-3 py-2 font-mono"
                placeholder="e.g. IN-MH"
              />
            </div>
            {formData.id && (
              <div className="flex items-center gap-2 mt-4">
                <input
                  type="checkbox"
                  id="unitActive"
                  checked={formData.status === 'ACTIVE'}
                  onChange={e => setFormData(f => ({ ...f, status: e.target.checked ? 'ACTIVE' : 'INACTIVE' }))}
                  className="w-4 h-4 rounded"
                />
                <label htmlFor="unitActive" className="text-sm font-medium">Active</label>
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

      {/* Table */}
      {loading ? (
        <div className="py-12 text-center text-zinc-500 animate-pulse">Loading units…</div>
      ) : (
        <div className="border border-zinc-800 rounded-xl overflow-hidden bg-zinc-900/30">
          <table className="w-full text-left text-sm">
            <thead className="bg-zinc-900/80 border-b border-zinc-800 text-zinc-400">
              <tr>
                <th className="px-4 py-3 font-medium">Code</th>
                <th className="px-4 py-3 font-medium">Name</th>
                <th className="px-4 py-3 font-medium">Level</th>
                <th className="px-4 py-3 font-medium">Parent</th>
                <th className="px-4 py-3 font-medium">Status</th>
                {canEdit && <th className="px-4 py-3 font-medium text-right">Actions</th>}
              </tr>
            </thead>
            <tbody className="divide-y divide-zinc-800/50">
              {units.length === 0 ? (
                <tr><td colSpan={6} className="px-6 py-8 text-center text-zinc-500">No units match your filters.</td></tr>
              ) : units.map(item => (
                <tr key={item.id} className="hover:bg-zinc-800/30 transition-colors">
                  <td className="px-4 py-3 font-mono text-xs text-zinc-400">{item.official_code}</td>
                  <td className="px-4 py-3 font-medium">
                    {item.display_name}
                    {item.official_name !== item.display_name && (
                      <div className="text-xs text-zinc-500">{item.official_name}</div>
                    )}
                  </td>
                  <td className="px-4 py-3 text-xs text-zinc-500">{item.level_number}. {item.level_label}</td>
                  <td className="px-4 py-3 text-xs text-zinc-500">
                    {item.parent_name ? (
                      <span className="flex items-center gap-1"><ChevronRight className="w-3 h-3" />{item.parent_name}</span>
                    ) : <span className="text-zinc-700">—</span>}
                  </td>
                  <td className="px-4 py-3">
                    {item.status === 'ACTIVE'
                      ? <span className="inline-flex items-center gap-1 text-emerald-400 text-xs font-medium"><CheckCircle2 className="w-3 h-3" /> Active</span>
                      : <span className="inline-flex items-center gap-1 text-red-400 text-xs font-medium"><XCircle className="w-3 h-3" /> Inactive</span>
                    }
                  </td>
                  {canEdit && (
                    <td className="px-4 py-3 text-right flex items-center justify-end gap-2">
                      <button onClick={() => openEdit(item)} className="p-1.5 text-zinc-400 hover:text-white rounded hover:bg-zinc-700 transition-colors">
                        <Edit2 className="w-4 h-4" />
                      </button>
                      <button
                        onClick={() => toggleStatus(item)}
                        className={`text-xs px-2 py-1 rounded font-medium transition-colors ${item.status === 'ACTIVE' ? 'text-red-400 hover:bg-red-900/30' : 'text-emerald-400 hover:bg-emerald-900/30'}`}
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
