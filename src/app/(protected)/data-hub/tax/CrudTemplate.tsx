'use client'

import React, { useState, useEffect } from 'react';
import { Loader2, Plus, Edit, ShieldAlert } from 'lucide-react';

export default function GenericCrudPage({ 
  title, 
  apiPath, 
  columns, 
  defaultForm 
}: { 
  title: string, 
  apiPath: string, 
  columns: {key: string, label: string}[],
  defaultForm: any 
}) {
  const [data, setData] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState<any>(defaultForm);
  const [isEdit, setIsEdit] = useState(false);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    fetchData();
  }, [apiPath]);

  const fetchData = async () => {
    setLoading(true);
    try {
      const res = await fetch(apiPath);
      if (!res.ok) throw new Error('Failed to fetch');
      setData(await res.json());
    } catch (err: any) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    setError('');
    try {
      const method = isEdit ? 'PATCH' : 'POST';
      const res = await fetch(apiPath, {
        method,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(form)
      });
      if (!res.ok) {
         const err = await res.json();
         throw new Error(err.error || 'Failed to save');
      }
      setShowForm(false);
      fetchData();
    } catch (err: any) {
      setError(err.message);
    } finally {
      setSaving(false);
    }
  };

  const openEdit = (item: any) => {
    setForm(item);
    setIsEdit(true);
    setShowForm(true);
  };

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-white">{title}</h1>
        </div>
        <button 
          onClick={() => { setForm(defaultForm); setIsEdit(false); setShowForm(true); }}
          className="bg-blue-600 hover:bg-blue-500 text-white px-4 py-2 rounded flex items-center gap-2"
        >
          <Plus className="w-4 h-4" /> Add New
        </button>
      </div>

      {error && (
        <div className="bg-red-500/10 border border-red-500 text-red-500 p-4 rounded flex items-center gap-3">
          <ShieldAlert className="w-5 h-5" /> {error}
        </div>
      )}

      {showForm ? (
        <form onSubmit={handleSave} className="bg-zinc-900 border border-zinc-800 p-6 rounded-xl space-y-4">
          <h3 className="text-lg font-semibold text-white">{isEdit ? 'Edit' : 'Create'} Record</h3>
          <div className="grid grid-cols-2 gap-4">
             {Object.keys(defaultForm).map(k => (
               <div key={k}>
                 <label className="block text-sm text-zinc-400 mb-1 capitalize">{k.replace(/_/g, ' ')}</label>
                 <input 
                   type="text" 
                   value={form[k] || ''}
                   onChange={e => setForm({...form, [k]: e.target.value})}
                   className="w-full bg-black border border-zinc-700 rounded p-2 text-white"
                   required
                 />
               </div>
             ))}
          </div>
          <div className="flex justify-end gap-3 pt-4">
             <button type="button" onClick={() => setShowForm(false)} className="text-zinc-400 hover:text-white px-4 py-2">Cancel</button>
             <button type="submit" disabled={saving} className="bg-blue-600 text-white px-4 py-2 rounded">
               {saving ? 'Saving...' : 'Save Record'}
             </button>
          </div>
        </form>
      ) : (
        <div className="bg-zinc-900 border border-zinc-800 rounded-xl overflow-hidden">
          {loading ? (
            <div className="p-8 flex justify-center text-zinc-500"><Loader2 className="w-6 h-6 animate-spin" /></div>
          ) : data.length === 0 ? (
            <div className="p-8 text-center text-zinc-500">No records found.</div>
          ) : (
            <table className="w-full text-left text-sm text-zinc-300">
              <thead className="bg-zinc-800/50 text-zinc-400">
                <tr>
                  {columns.map(c => <th key={c.key} className="px-4 py-3">{c.label}</th>)}
                  <th className="px-4 py-3 w-20 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-zinc-800">
                {data.map(item => (
                  <tr key={item.id} className="hover:bg-zinc-800/30">
                    {columns.map(c => <td key={c.key} className="px-4 py-3">{String(item[c.key] || '')}</td>)}
                    <td className="px-4 py-3 text-right">
                      <button onClick={() => openEdit(item)} className="text-zinc-400 hover:text-white">
                        <Edit className="w-4 h-4" />
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      )}
    </div>
  );
}
