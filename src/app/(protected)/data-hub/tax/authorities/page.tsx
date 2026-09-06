import { getAuthContext } from '@/utils/auth'
import { redirect } from 'next/navigation'
import { createAdminClient } from '@/utils/supabase/admin'
import TaxAuthoritiesClient from './TaxAuthoritiesClient'

export default async function TaxAuthoritiesPage(props: { searchParams: Promise<{ country?: string }> }) {
  const { staff } = await getAuthContext()
  if (!staff) redirect('/login')

  const searchParams = await props.searchParams
  const countryId = searchParams.country

  // Use admin client — tax_authorities has RLS enabled with no user policies
  const admin = createAdminClient()

  // Fetch all authorities (admin bypasses RLS)
  const { data: authorities, error } = await admin
    .from('tax_authorities')
    .select('*')
    .order('authority_name')

  // Fetch country name for display
  let countryName = ''
  if (countryId) {
    const { data: supabase_client } = await admin.from('countries').select('display_name, iso2').eq('id', countryId).single()
    if (supabase_client) countryName = `${supabase_client.display_name} (${supabase_client.iso2})`
  }

  const filtered = countryId
    ? (authorities || []).filter((a: any) => a.country_id === countryId)
    : (authorities || [])

  return (
    <TaxAuthoritiesClient
      authorities={filtered}
      allAuthorities={authorities || []}
      countryId={countryId || ''}
      countryName={countryName}
      dbError={error?.message}
    />
  )
}
