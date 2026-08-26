'use client'

import { useState } from 'react'
import { Plus, Edit2, CheckCircle2, XCircle } from 'lucide-react'
import { createLevel, updateLevel } from '../actions'

const CATALOG_ADMIN_ROLES = ['PLATFORM_SUPERADMIN', 'CATALOG_MANAGER']

interface Level {
  id: string
  country_id: string
  level_number: number
  level_key: string
  display_label: string
  status: string
  created_at: string
  updated_at: string
}

interface Props {
  initialLevels: Level[]
  country: { id: string; display_name: string } | null
  staffRole: string
  staffId: string
}

const emptyForm = { id: '', level_number: 0, level_key: '', display_label: '', status: 'ACTIVE' }

export function LevelsClient({ initialLevels, country, staffRole }: Props) {
  const [levels, setLevels] = useState<Level[]>(initialLevels)
  const [isFormOpen, setIsFormOpen] = useState(false)
  const [formData, setFormData] = useState({ ...emptyForm })
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const canEdit = CATALOG_ADMIN_ROLES.includes(staffRole)
  const nextNumber = levels.length > 0 ? Math.max(...levels.map(l => l.level_number)) + 1 : 1

  const openCreate = () => {
    setFormData({ ...emptyForm, level_number: nextNumber })
    setError(null)
    setIsFormOpen(true)
  }

  const openEdit = (item: Level) => {
    setFormData({ id: item.id, level_number: item.level_number, level_key: item.level_key, display_label: item.display_label, status: item.status })
    setError(null)
    setIsFormOpen(true)
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!country) return
    setLoading(true)
    setError(null)
    try {
      if (formData.id) {
        const updated = await updateLevel(formData.id, { display_label: formData.display_label, status: formData.status })
        setLevels(levels.map(l => l.id === updated.id ? { ...l, ...updated } : l))
      } else {
        const created = await createLevel({
          country_id: country.id,
          level_number: formData.level_number,
          level_key: formData.level_key.toUpperCase().replace(/\s+/g, '_'),
          display_label: formData.display_label,
        })
        setLevels([...levels, created])
      }
      setIsFormOpen(false)
    } catch (err: any) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  const toggleStatus = async (item: Level) => {
    if (!canEdit) return
    try {
      const updated = await updateLevel(item.id, {
        display_label: item.display_label,
        status: item.status === 'ACTIVE' ? 'INACTIVE' : 'ACTIVE',
      })
      setLevels(levels.map(l => l.id === updated.id ? { ...l, ...updated } : l))
    } catch (err: any) {
      setError(err.message)
    }
  }

  return (
    <div className="space-y-6">
      {country && (
        <div className="flex items-center justify-between">
          <div className="text-sm text-zinc-500">
            Country: <span className="text-zinc-300 font-medium">{country.display_name}</span>
          </div>
          {canEdit && (
            <button
              onClick={openCreate}
              className="flex items-center gap-2 bg-teal-600 hover:bg-teal-700 text-white px-4 py-2 rounded-lg text-sm font-medium transition-colors"
            >
              <Plus className="w-4 h-4" /> Add Level
            </button>
          )}
        </div>
      )}

      {error && (
        <div className="p-4 bg-red-900/50 border border-red-800 text-red-200 rounded-lg text-sm">{error}</div>
      )}

      {isFormOpen && (
        <form onSubmit={handleSubmit} className="p-6 bg-zinc-900/50 border border-zinc-800 rounded-xl space-y-4">
          <h3 className="font-semibold">{formData.id ? 'Edit Level' : 'Add Level'}</h3>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium mb-1">Level Number</label>
              <input
                type="number"
                required
                disabled={!!formData.id}
                value={formData.level_number}
                onChange={e => setFormData({ ...formData, level_number: parseInt(e.target.value) })}
                className="w-full bg-zinc-950 border border-zinc-800 rounded-lg px-3 py-2 disabled:opacity-50"
              />
            </div>
            <div>
              <label className="block text-sm font-medium mb-1">Level Key</label>
              <input
                required
                disabled={!!formData.id}
                value={formData.level_key}
                placeholder="e.g. STATE_UT"
                onChange={e => setFormData({ ...formData, level_key: e.target.value })}
                className="w-full bg-zinc-950 border border-zinc-800 rounded-lg px-3 py-2 disabled:opacity-50 font-mono text-sm"
              />
            </div>
            <div className="col-span-2">
              <label className="block text-sm font-medium mb-1">Display Label</label>
              <input
                required
                value={formData.display_label}
                placeholder="e.g. State / Union Territory"
                onChange={e => setFormData({ ...formData, display_label: e.target.value })}
                className="w-full bg-zinc-950 border border-zinc-800 rounded-lg px-3 py-2"
              />
            </div>
            {formData.id && (
              <div className="col-span-2 flex items-center gap-2">
                <input
                  type="checkbox"
                  id="levelActive"
                  checked={formData.status === 'ACTIVE'}
                  onChange={e => setFormData({ ...formData, status: e.target.checked ? 'ACTIVE' : 'INACTIVE' })}
                  className="w-4 h-4 rounded"
                />
                <label htmlFor="levelActive" className="text-sm font-medium">Active</label>
              </div>
            )}
          </div>
          <div className="flex justify-end gap-2 pt-2">
            <button type="button" onClick={() => setIsFormOpen(false)} className="px-4 py-2 hover:bg-zinc-800 rounded-lg text-sm font-medium">Cancel</button>
            <button type="submit" disabled={loading} className="px-4 py-2 bg-teal-600 hover:bg-teal-700 text-white rounded-lg text-sm font-medium disabled:opacity-50">
              {loading ? 'Saving…' : 'Save'}
            </button>
          </div>
        </form>
      )}

      <div className="border border-zinc-800 rounded-xl overflow-hidden bg-zinc-900/30">
        <table className="w-full text-left text-sm">
          <thead className="bg-zinc-900/80 border-b border-zinc-800 text-zinc-400">
            <tr>
              <th className="px-6 py-3 font-medium">No.</th>
              <th className="px-6 py-3 font-medium">Key</th>
              <th className="px-6 py-3 font-medium">Display Label</th>
              <th className="px-6 py-3 font-medium">Status</th>
              {canEdit && <th className="px-6 py-3 font-medium text-right">Actions</th>}
            </tr>
          </thead>
          <tbody className="divide-y divide-zinc-800/50">
            {levels.length === 0 ? (
              <tr><td colSpan={5} className="px-6 py-8 text-center text-zinc-500">No geography levels configured.</td></tr>
            ) : levels.sort((a, b) => a.level_number - b.level_number).map(item => (
              <tr key={item.id} className="hover:bg-zinc-800/30 transition-colors">
                <td className="px-6 py-3 font-mono text-zinc-300">{item.level_number}</td>
                <td className="px-6 py-3 font-mono text-xs text-zinc-400">{item.level_key}</td>
                <td className="px-6 py-3 font-medium">{item.display_label}</td>
                <td className="px-6 py-3">
                  {item.status === 'ACTIVE'
                    ? <span className="inline-flex items-center gap-1 text-emerald-400 text-xs font-medium"><CheckCircle2 className="w-3 h-3" /> Active</span>
                    : <span className="inline-flex items-center gap-1 text-red-400 text-xs font-medium"><XCircle className="w-3 h-3" /> Inactive</span>
                  }
                </td>
                {canEdit && (
                  <td className="px-6 py-3 text-right flex items-center justify-end gap-2">
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
    </div>
  )
}
