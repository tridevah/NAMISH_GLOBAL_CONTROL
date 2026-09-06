import { getAuthContext } from '@/utils/auth'
import { redirect } from 'next/navigation'
import { createAdminClient } from '@/utils/supabase/admin'
import HsnSacClient from './HsnSacClient'

export default async function HsnSacPage() {
    const { staff } = await getAuthContext()
    if (!staff) redirect('/login')

    const admin = createAdminClient()

    // Fetch first page of records server-side for initial render
    const { data: codes, error, count } = await admin
        .from('hsn_sac')
        .select('id, code, code_type, description, chapter, goods_or_service, status, effective_from, effective_to, official_source, source_reference', { count: 'exact' })
        .in('status', ['ACTIVE', 'TOP_LEVEL_CLASSIFICATION_ONLY'])
        .order('code_type', { ascending: true })
        .order('code',      { ascending: true })
        .limit(100)

    // Server-side counts by code_type — correct labels for cards
    const { count: hsnCount } = await admin
        .from('hsn_sac')
        .select('*', { count: 'exact', head: true })
        .eq('code_type', 'HSN')
        .eq('status', 'ACTIVE')

    const { count: sacCount } = await admin
        .from('hsn_sac')
        .select('*', { count: 'exact', head: true })
        .eq('code_type', 'SAC')
        .eq('status', 'ACTIVE')

    return (
        <HsnSacClient
            initialCodes={codes || []}
            initialTotal={count ?? 0}
            hsnCount={hsnCount ?? 0}
            sacCount={sacCount ?? 0}
            dbError={error?.message}
        />
    )
}