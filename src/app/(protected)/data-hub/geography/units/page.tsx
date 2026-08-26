import { getAuthContext } from '@/utils/auth'
import { redirect } from 'next/navigation'
import { getCountries, getLevels, getUnits } from '../actions'
import { UnitsClient } from './client'

export default async function UnitsPage() {
  const { staff } = await getAuthContext()
  if (!staff) redirect('/login')

  const countries = await getCountries().catch(() => [])
  const indiaCountry = countries[0] ?? null
  const levels = indiaCountry ? await getLevels(indiaCountry.id).catch(() => []) : []
  const unitsData = indiaCountry
    ? await getUnits({ country_id: indiaCountry.id, limit: 200 }).catch(() => ({ rows: [], total: 0 }))
    : { rows: [], total: 0 }

  return (
    <div>
      <h1 className="text-2xl font-bold tracking-tight mb-1">Geography Units</h1>
      <p className="text-zinc-400 mb-6">Manage specific geography units and hierarchy mapping.</p>
      <UnitsClient
        initialUnits={unitsData.rows}
        initialTotal={unitsData.total}
        country={indiaCountry}
        levels={levels}
        staffRole={staff.role}
      />
    </div>
  )
}
