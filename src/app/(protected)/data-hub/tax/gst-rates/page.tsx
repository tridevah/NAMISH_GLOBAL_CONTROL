import { getAuthContext } from '@/utils/auth'
import { redirect } from 'next/navigation'
import { createAdminClient } from '@/utils/supabase/admin'
import GstRatesClient from './GstRatesClient'

export default async function GstRatesPage() {
    const { staff } = await getAuthContext()
    if (!staff) redirect('/login')

    const admin = createAdminClient()
    const { data: rates, error } = await admin
        .from('gst_rate_master')
        .select(
            'id, country_id, rate_percent, rate_name, category, is_current, status,' +
            ' notification_number, notification_date, official_source, source_reference, notes,' +
            ' effective_from, effective_to, created_at,' +
            ' rate_code, usage_scope, erp_visibility, statutory_rate_percent,' +
            ' effective_display_percent, valuation_basis, itc_policy, conditions'
        )
        .order('usage_scope',  { ascending: true })
        .order('rate_percent', { ascending: true })

    return <GstRatesClient rates={(rates as any[]) || []} dbError={error?.message} />
}
