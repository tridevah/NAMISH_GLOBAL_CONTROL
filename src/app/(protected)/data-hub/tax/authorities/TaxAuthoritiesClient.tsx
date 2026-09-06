'use client'

import React, { useState } from 'react'
import { Tag, AlertCircle, ExternalLink } from 'lucide-react'

interface Authority {
  id: string
  country_id: string
  jurisdiction_id?: string
  tax_type: string
  authority_name: string
  official_website?: string
  provenance_reference?: string
  status: string
}

export default function TaxAuthoritiesClient({
  authorities,
  allAuthorities,
  countryId,
  countryName,
  dbError
}: {
  authorities: Authority[]
  allAuthorities: Authority[]
  countryId: string
  countryName: string
  dbError?: string
}) {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight text-white flex items-center gap-2 mb-1">
          <Tag className="w-6 h-6 text-blue-400" />
          Tax Authorities
        </h1>
        <p className="text-zinc-400 text-sm">
          {countryName ? `Showing authorities for ${countryName}` : 'Showing all tax authorities.'}
          {' '}<span className="text-zinc-500">({authorities.length} of {allAuthorities.length} total)</span>
        </p>
      </div>

      {dbError && (
        <div className="p-4 border border-red-500/30 bg-red-500/10 rounded-lg flex items-center gap-3 text-red-400 text-sm">
          <AlertCircle className="w-5 h-5 shrink-0" />
          Database error: {dbError}
        </div>
      )}

      {authorities.length === 0 ? (
        <div className="p-10 border border-zinc-800 rounded-xl bg-zinc-900/30 text-center text-zinc-500">
          No tax authorities found{countryName ? ` for ${countryName}` : ''}.
        </div>
      ) : (
        <div className="bg-zinc-900 border border-zinc-800 rounded-xl overflow-hidden">
          <table className="w-full text-left text-sm">
            <thead className="bg-zinc-800/50 text-zinc-400">
              <tr>
                <th className="px-4 py-3">Authority</th>
                <th className="px-4 py-3">Tax Type</th>
                <th className="px-4 py-3">Status</th>
                <th className="px-4 py-3">Website</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-zinc-800">
              {authorities.map((a) => (
                <tr key={a.id} className="hover:bg-zinc-800/30">
                  <td className="px-4 py-3 text-white font-medium">{a.authority_name}</td>
                  <td className="px-4 py-3">
                    <span className="px-2 py-0.5 bg-teal-500/10 text-teal-400 rounded text-xs font-mono">{a.tax_type}</span>
                  </td>
                  <td className="px-4 py-3">
                    <span className={`px-2 py-0.5 rounded-full text-xs ${a.status === 'ACTIVE' ? 'bg-green-500/10 text-green-400' : 'bg-zinc-700 text-zinc-400'}`}>
                      {a.status}
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    {a.official_website ? (
                      <a href={a.official_website} target="_blank" rel="noopener noreferrer"
                        className="text-blue-400 hover:text-blue-300 flex items-center gap-1 text-xs">
                        {a.official_website.replace(/^https?:\/\//, '').split('/')[0]}
                        <ExternalLink className="w-3 h-3" />
                      </a>
                    ) : (
                      <span className="text-zinc-600 text-xs">—</span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
