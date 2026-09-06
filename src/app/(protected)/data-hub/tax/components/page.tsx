import { getAuthContext } from '@/utils/auth'
import { redirect } from 'next/navigation'
import { createClient } from '@/utils/supabase/server'
import { AlertCircle } from 'lucide-react'

export default async function Page(props: { searchParams: Promise<{ country?: string }> }) {
  const { staff } = await getAuthContext()
  if (!staff) redirect('/login')

  const searchParams = await props.searchParams
  let activeCountryId = searchParams.country
  const supabase = await createClient()

  if (activeCountryId) {
    const { data: validCountry } = await supabase.from('countries').select('id').eq('id', activeCountryId).single()
    if (!validCountry) {
      activeCountryId = undefined
    }
  }

  if (!activeCountryId) {
    const { data: india } = await supabase.from('countries').select('id').eq('iso2', 'IN').single()
    if (india) activeCountryId = india.id
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight mb-2 text-white">Tax Data: components</h1>
        <p className="text-zinc-400 mb-6">Manage components compliance models.</p>
      </div>
      <div className="p-12 text-center border border-dashed border-red-500/30 rounded-xl bg-red-500/5">
        <AlertCircle className="w-12 h-12 text-red-500/50 mx-auto mb-4" />
        <h2 className="text-lg font-medium text-white mb-2">NOT CONFIGURED</h2>
        <p className="text-zinc-400">COMING SOON: This module is currently in development and not yet available for production use.</p>
      </div>
    </div>
  )
}