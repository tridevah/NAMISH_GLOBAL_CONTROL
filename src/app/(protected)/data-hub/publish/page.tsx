'use client';

import { useState } from 'react'

export default function PublishPage() {
  const [draftId, setDraftId] = useState<string | null>(null)
  const [version, setVersion] = useState<string>('')
  const [counts, setCounts] = useState<any>(null)
  const [diffs, setDiffs] = useState<any>(null)
  const [deliveryStatus, setDeliveryStatus] = useState<string | null>(null)
  const [reviewData, setReviewData] = useState<any>(null)
  const [loading, setLoading] = useState(false)
  const [message, setMessage] = useState('')

  const fetchDraft = async (id: string) => {
    setLoading(true)
    setMessage('Fetching draft details...')
    try {
      const res = await fetch(`/api/data-hub/publish/draft?id=${id}`)
      const data = await res.json()
      if (!res.ok) throw new Error(data.error)
      setDraftId(id)
      setCounts(data.counts)
      setDiffs(data.diffs)
      const getErpDeliveryStatus = (delivery: any, draft_status: string) => {
        if (draft_status === 'DRAFT') return 'DRAFT'
        if (!delivery) return 'UNKNOWN'
        if (delivery.lookup_status === 'EVENT_NOT_FOUND') return 'EVENT_NOT_FOUND'
        if (delivery.event_status === 'NOT_YET_PUBLISHED') return 'DRAFT'

        const erpEndpointId = '4eb4da3b-c802-4d44-98b4-9859528e6beb'
        const erp = delivery.deliveries?.find((d: any) => d.endpoint_id === erpEndpointId)
        
        if (!erp) return 'ERP_DELIVERY_NOT_FOUND'

        if (erp.delivery_status === 'SUCCESS') return 'Delivered'
        if (erp.delivery_status === 'DEAD') return 'Failed'
        if (erp.delivery_status === 'PENDING' || erp.delivery_status === 'CLAIMED') return 'Pending'
        return erp.delivery_status
      }
      
      setDeliveryStatus(getErpDeliveryStatus(data.delivery, data.draft_status))
      setReviewData(data)
      setVersion(data.draft_version)
      setMessage('Draft loaded successfully.')
    } catch (e: any) {
      setMessage(`Error: ${e.message}`)
    } finally {
      setLoading(false)
    }
  }

  const handleCreateDraft = async () => {
    if (!version.trim()) {
      setMessage('Error: Version is required.')
      return
    }
    setLoading(true)
    setMessage('Creating draft...')
    try {
      const res = await fetch('/api/data-hub/publish/draft', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ version: version.trim() })
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.error)
      
      await fetchDraft(data.releaseId)
    } catch (e: any) {
      setMessage(`Error: ${e.message}`)
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
        body: JSON.stringify({ 
          releaseId: draftId,
          baselineReleaseId: reviewData?.baseline_release_id || null
        })
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.error)
      setMessage(`Successfully published release.`)
      await fetchDraft(draftId) // Refresh status
    } catch (e: any) {
      setMessage(`Error: ${e.message}`)
      setLoading(false)
    }
  }

  return (
    <div className="p-8 max-w-4xl mx-auto space-y-6">
      <h1 className="text-2xl font-bold">Review & Publish to ERP</h1>
      
      <div className="space-y-4 p-4 border rounded bg-gray-50">
        <div>
          <label className="block text-sm font-medium mb-1">Release Version</label>
          <input 
            type="text" 
            value={version}
            onChange={e => setVersion(e.target.value)}
            placeholder="e.g. v8.3.0"
            className="border p-2 rounded w-full max-w-md"
            disabled={loading || !!draftId} // Disabled if viewing a draft
          />
        </div>
        
        {!draftId && (
          <div className="flex gap-4">
            <button 
              onClick={() => handleCreateDraft()}
              disabled={loading || !version}
              className="bg-blue-600 text-white px-4 py-2 rounded disabled:opacity-50"
            >
              Generate Business Snapshot
            </button>
          </div>
        )}
        
        {draftId && (
          <button
            onClick={() => { setDraftId(null); setCounts(null); setVersion(''); setDeliveryStatus(null); setMessage(''); }}
            className="text-sm text-blue-600 underline"
          >
            Clear / Start Over
          </button>
        )}
      </div>

      {message && <div className="p-4 bg-white border border-gray-200 shadow-sm rounded text-gray-800">{message}</div>}

      {draftId && counts && (
        <div className="border p-6 rounded-lg bg-white shadow space-y-4">
          <div className="flex justify-between items-center border-b pb-4">
            <div>
              <h2 className="text-xl font-semibold">Draft Review ({version})</h2>
              {reviewData?.baseline_sequence && (
                <p className="text-xs text-gray-500 mt-1">
                  Baseline: Seq {reviewData.baseline_sequence} ({reviewData.baseline_version})
                </p>
              )}
            </div>
            <div className="flex items-center gap-3">
              <div className={`px-3 py-1 rounded text-sm font-bold ${
                  deliveryStatus === 'DRAFT' ? 'bg-yellow-100 text-yellow-800' :
                  deliveryStatus === 'Delivered' ? 'bg-green-100 text-green-800' :
                  deliveryStatus === 'Failed' ? 'bg-red-100 text-red-800' :
                  deliveryStatus === 'Pending' ? 'bg-blue-100 text-blue-800' :
                  deliveryStatus === 'ERP_DELIVERY_NOT_FOUND' ? 'bg-gray-200 text-gray-800' :
                  deliveryStatus === 'EVENT_NOT_FOUND' ? 'bg-red-100 text-red-800' :
                  'bg-gray-100 text-gray-800'
              }`}>
                Status: {deliveryStatus}
              </div>
              <button 
                onClick={() => fetchDraft(draftId)}
                className="text-gray-500 hover:text-gray-800 bg-gray-100 hover:bg-gray-200 px-3 py-1 rounded text-sm"
              >
                Refresh
              </button>
            </div>
          </div>
          <p className="text-sm text-gray-500 font-mono">ID: {draftId}</p>
          
          <div className="grid grid-cols-3 gap-4 py-4">
            {Object.entries(counts).map(([type, count]) => (
              <div key={type} className="bg-gray-50 p-4 rounded text-center border">
                <div className="text-2xl font-bold">{String(count)}</div>
                <div className="text-sm text-gray-600 font-medium">{type}</div>
                {diffs && diffs[type] && (
                  <div className="mt-2 pt-2 border-t text-xs text-left grid grid-cols-2 gap-1 text-gray-500">
                    <div className={diffs[type].added > 0 ? "text-green-600 font-bold" : ""}>+ {diffs[type].added}</div>
                    <div className={diffs[type].removed > 0 ? "text-red-600 font-bold" : ""}>- {diffs[type].removed}</div>
                    <div className={diffs[type].modified > 0 ? "text-blue-600 font-bold" : ""}>~ {diffs[type].modified}</div>
                    <div>= {diffs[type].unchanged}</div>
                  </div>
                )}
              </div>
            ))}
          </div>

          {reviewData?.draft_status === 'DRAFT' && (
            <button 
              onClick={handlePublish}
              disabled={loading}
              className="w-full bg-green-600 hover:bg-green-700 text-white px-4 py-3 rounded font-bold disabled:opacity-50 transition-colors"
            >
              {loading ? 'Processing...' : 'Confirm & Publish to Outbox'}
            </button>
          )}
        </div>
      )}
    </div>
  )
}

