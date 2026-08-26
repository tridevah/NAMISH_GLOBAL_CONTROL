import { getAuthContext } from '@/utils/auth'
import { redirect } from 'next/navigation'
import { getCountries, getPostalCodes } from '../actions'
import { PostalCodesClient } from './client'

export default async function PostalCodesPage() {
  const { staff } = await getAuthContext()
  if (!staff) redirect('/login')

  const countries = await getCountries().catch(() => [])
  const indiaCountry = countries[0] ?? null
  const postalData = indiaCountry
    ? await getPostalCodes({ country_id: indiaCountry.id, limit: 100 }).catch(() => ({ rows: [], total: 0 }))
    : { rows: [], total: 0 }

  return (
    <div>
      <h1 className="text-2xl font-bold tracking-tight mb-1">Postal Codes</h1>
      <p className="text-zinc-400 mb-6">Manage postal codes and map them to valid geography units.</p>
      <PostalCodesClient
        initialPostalCodes={postalData.rows}
        initialTotal={postalData.total}
        country={indiaCountry}
        staffRole={staff.role}
      />
    </div>
  )
}
