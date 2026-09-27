'use client';

import { useState } from 'react'

export default function PublishPage() {
  const [draftId, setDraftId] = useState<string | null>(null)
  const [counts, setCounts] = useState<any>(null)
  const [loading, setLoading] = useState(false)
  const [message, setMessage] = useState('')
  const [published, setPublished] = useState(false)

  const handleCreateDraft = async (cleanup: boolean) => {
    setLoading(true)
    setMessage('Creating draft...')
    try {
      const res = await fetch('/api/data-hub/publish/draft', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ version: `v8.2.0-${cleanup ? 'cleanup' : 'business'}`, include_cleanup: cleanup })
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.error)
      setDraftId(data.releaseId)
      setCounts(data.counts)
      setMessage('Draft created successfully.')
      setPublished(false)
    } catch (e: any) {
      setMessage(`Error: ${e.message}`)
    } finally {
      setLoading(false)
    }
  }

  const handlePublish = async () => {
    if (!draftId) return
    setLoading(true)
    setMessage('Publishing to ERP...')
    try {
      const res = await fetch('/api/data-hub/publish/commit', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ releaseId: draftId })
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.error)
      setMessage(`Successfully published release ${draftId}`)
      setPublished(true)
    } catch (e: any) {
      setMessage(`Error: ${e.message}`)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="p-8 max-w-4xl mx-auto space-y-6">
      <h1 className="text-2xl font-bold">Review & Publish to ERP</h1>
      
      <div className="flex gap-4">
        <button 
          onClick={() => handleCreateDraft(false)}
          disabled={loading}
          className="bg-blue-600 text-white px-4 py-2 rounded disabled:opacity-50"
        >
          Generate Business Snapshot (Standard)
        </button>
        <button 
          onClick={() => handleCreateDraft(true)}
          disabled={loading}
          className="bg-purple-600 text-white px-4 py-2 rounded disabled:opacity-50"
        >
          Generate Cleanup Snapshot (Includes Inactive)
        </button>
      </div>

      {message && <div className="p-4 bg-gray-100 rounded text-gray-800">{message}</div>}

      {draftId && counts && !published && (
        <div className="border p-6 rounded-lg bg-white shadow space-y-4">
          <h2 className="text-xl font-semibold">Draft Review</h2>
          <p className="text-sm text-gray-500">ID: {draftId}</p>
          
          <div className="grid grid-cols-3 gap-4 py-4">
            {Object.entries(counts).map(([type, count]) => (
              <div key={type} className="bg-gray-50 p-4 rounded text-center border">
                <div className="text-2xl font-bold">{String(count)}</div>
                <div className="text-sm text-gray-600 font-medium">{type}</div>
              </div>
            ))}
          </div>

          <button 
            onClick={handlePublish}
            disabled={loading}
            className="w-full bg-green-600 hover:bg-green-700 text-white px-4 py-3 rounded font-bold disabled:opacity-50"
          >
            {loading ? 'Processing...' : 'Confirm & Publish to Outbox'}
          </button>
        </div>
      )}
    </div>
  )
}
