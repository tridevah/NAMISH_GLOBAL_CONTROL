import { getAuthContext } from '@/utils/auth'
import { redirect } from 'next/navigation'
import { getLevels, getCountries } from '../actions'
import { LevelsClient } from './client'

export default async function LevelsPage() {
  const { staff } = await getAuthContext()
  if (!staff) redirect('/login')

  const countries = await getCountries().catch(() => [])
  const indiaCountry = countries[0] ?? null
  const levels = indiaCountry ? await getLevels(indiaCountry.id).catch(() => []) : []

  return (
    <div>
      <h1 className="text-2xl font-bold tracking-tight mb-1">Geography Levels</h1>
      <p className="text-zinc-400 mb-6">Manage country-specific geography hierarchy levels.</p>
      <LevelsClient
        initialLevels={levels}
        country={indiaCountry}
        staffRole={staff.role}
        staffId={staff.id}
      />
    </div>
  )
}
