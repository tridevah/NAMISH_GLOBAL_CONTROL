'use client'

import { useState, useEffect } from 'react'
import { getCountries, createCountry, updateCountry } from '../actions'
import { Plus, Edit2, CheckCircle2, XCircle } from 'lucide-react'

export default function CountriesClient({ role }: { role: string }) {
  const [data, setData] = useState<any[]>([])
  const [loadingData, setLoadingData] = useState(true)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [isFormOpen, setIsFormOpen] = useState(false)
  
  const canEdit = ['PLATFORM_SUPERADMIN', 'CATALOG_MANAGER'].includes(role)
  
  const [formData, setFormData] = useState({ id: '', iso2: '', iso3: '', numeric_code: '', official_name: '', display_name: '', default_currency_code: '', status: 'ACTIVE' })
  
  useEffect(() => {
    setLoadingData(true)
    getCountries()
      .then(res => setData(res))
      .catch(err => setError(err.message))
      .finally(() => setLoadingData(false))
  }, [])

  const openCreate = () => {
    setFormData({ id: '', iso2: '', iso3: '', numeric_code: '', official_name: '', display_name: '', default_currency_code: '', status: 'ACTIVE' })
    setIsFormOpen(true)
  }
  
  const openEdit = (item: any) => {
    setFormData(item)
    setIsFormOpen(true)
  }
  
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    setError(null)
    try {
      if (formData.id) {
        const res = await updateCountry(formData.id, { 
          display_name: formData.display_name, 
          official_name: formData.official_name,
          default_currency_code: formData.default_currency_code,
          status: formData.status 
        })
        setData(data.map(d => d.id === res.id ? res : d))
      } else {
        const res = await createCountry({
          iso2: formData.iso2,
          iso3: formData.iso3,
          numeric_code: formData.numeric_code,
          display_name: formData.display_name,
          official_name: formData.official_name,
          default_currency_code: formData.default_currency_code
        })
        setData([...data, res])
      }
      setIsFormOpen(false)
    } catch (err: any) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  if (loadingData) return <div className="text-zinc-500 py-12 text-center animate-pulse">Loading countries...</div>

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">Countries Master</h1>
          <p className="text-zinc-400">Manage supported countries for the Global Data Hub.</p>
        </div>
        {canEdit && (
          <button 
            onClick={openCreate}
            className="flex items-center gap-2 bg-teal-600 hover:bg-teal-700 text-white px-4 py-2 rounded-lg font-medium transition-colors"
          >
            <Plus className="w-4 h-4" /> Add Country
          </button>
        )}
      </div>
      
      {error && (
        <div className="p-4 bg-red-900/50 border border-red-800 text-red-200 rounded-lg">
          {error}
        </div>
      )}
      
      {isFormOpen && (
        <form onSubmit={handleSubmit} className="p-6 bg-zinc-900/50 border border-zinc-800 rounded-xl space-y-4">
          <div className="grid grid-cols-3 gap-4">
            <div>
              <label className="block text-sm font-medium mb-1">ISO2</label>
              <input required disabled={!!formData.id} value={formData.iso2} onChange={e => setFormData({...formData, iso2: e.target.value.toUpperCase()})} className="w-full bg-zinc-950 border border-zinc-800 rounded-lg px-3 py-2 disabled:opacity-50" />
            </div>
            <div>
              <label className="block text-sm font-medium mb-1">ISO3</label>
              <input required disabled={!!formData.id} value={formData.iso3} onChange={e => setFormData({...formData, iso3: e.target.value.toUpperCase()})} className="w-full bg-zinc-950 border border-zinc-800 rounded-lg px-3 py-2 disabled:opacity-50" />
            </div>
            <div>
              <label className="block text-sm font-medium mb-1">Numeric Code</label>
              <input disabled={!!formData.id} value={formData.numeric_code || ''} onChange={e => setFormData({...formData, numeric_code: e.target.value})} className="w-full bg-zinc-950 border border-zinc-800 rounded-lg px-3 py-2 disabled:opacity-50" />
            </div>
            <div className="col-span-2">
              <label className="block text-sm font-medium mb-1">Official Name</label>
              <input required value={formData.official_name} onChange={e => setFormData({...formData, official_name: e.target.value})} className="w-full bg-zinc-950 border border-zinc-800 rounded-lg px-3 py-2" />
            </div>
            <div>
              <label className="block text-sm font-medium mb-1">Display Name</label>
              <input required value={formData.display_name} onChange={e => setFormData({...formData, display_name: e.target.value})} className="w-full bg-zinc-950 border border-zinc-800 rounded-lg px-3 py-2" />
            </div>
            <div>
              <label className="block text-sm font-medium mb-1">Default Currency</label>
              <input required value={formData.default_currency_code} onChange={e => setFormData({...formData, default_currency_code: e.target.value.toUpperCase()})} className="w-full bg-zinc-950 border border-zinc-800 rounded-lg px-3 py-2" />
            </div>
            {formData.id && (
              <div className="col-span-2 flex items-center gap-2 mt-6">
                <input type="checkbox" id="isActive" checked={formData.status === 'ACTIVE'} onChange={e => setFormData({...formData, status: e.target.checked ? 'ACTIVE' : 'INACTIVE'})} className="w-4 h-4 rounded border-zinc-800 bg-zinc-950" />
                <label htmlFor="isActive" className="text-sm font-medium">Active Status</label>
              </div>
            )}
          </div>
          <div className="flex justify-end gap-2 pt-2">
            <button type="button" onClick={() => setIsFormOpen(false)} className="px-4 py-2 hover:bg-zinc-800 rounded-lg text-sm font-medium">Cancel</button>
            <button type="submit" disabled={loading} className="px-4 py-2 bg-teal-600 hover:bg-teal-700 text-white rounded-lg text-sm font-medium disabled:opacity-50">
              {loading ? 'Saving...' : 'Save'}
            </button>
          </div>
        </form>
      )}

      <div className="border border-zinc-800 rounded-xl overflow-hidden bg-zinc-900/30">
        <table className="w-full text-left text-sm">
          <thead className="bg-zinc-900/80 border-b border-zinc-800 text-zinc-400">
            <tr>
              <th className="px-6 py-3 font-medium">ISO</th>
              <th className="px-6 py-3 font-medium">Display Name</th>
              <th className="px-6 py-3 font-medium">Currency</th>
              <th className="px-6 py-3 font-medium">Status</th>
              {canEdit && <th className="px-6 py-3 font-medium text-right">Actions</th>}
            </tr>
          </thead>
          <tbody className="divide-y divide-zinc-800/50">
            {data.length === 0 ? (
              <tr><td colSpan={5} className="px-6 py-8 text-center text-zinc-500">No countries configured.</td></tr>
            ) : data.map(item => (
              <tr key={item.id} className="hover:bg-zinc-800/30 transition-colors">
                <td className="px-6 py-3 font-medium">{item.iso2} / {item.iso3}</td>
                <td className="px-6 py-3">{item.display_name}</td>
                <td className="px-6 py-3 text-zinc-400">{item.default_currency_code}</td>
                <td className="px-6 py-3">
                  {item.status === 'ACTIVE' ? (
                    <span className="inline-flex items-center gap-1 text-emerald-400 text-xs font-medium"><CheckCircle2 className="w-3 h-3"/> Active</span>
                  ) : (
                    <span className="inline-flex items-center gap-1 text-red-400 text-xs font-medium"><XCircle className="w-3 h-3"/> Inactive</span>
                  )}
                </td>
                {canEdit && (
                  <td className="px-6 py-3 text-right">
                    <button onClick={() => openEdit(item)} className="p-1.5 text-zinc-400 hover:text-white rounded hover:bg-zinc-700 transition-colors">
                      <Edit2 className="w-4 h-4" />
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
