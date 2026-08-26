import { getAuthContext } from '@/utils/auth'
import CountriesClient from './client'
import { redirect } from 'next/navigation'

export const dynamic = 'force-dynamic'

export default async function CountriesPage() {
  const { staff } = await getAuthContext()
  if (!staff) redirect('/login')

  return <CountriesClient role={staff.role} />
}
