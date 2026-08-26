'use server'

import { getAuthContext } from '@/utils/auth'
import { createAdminClient } from '@/utils/supabase/admin'
import { revalidatePath } from 'next/cache'

async function logAudit(staffId: string, action: string, resource: string, resourceId: string | null, payload: any) {
  const adminSupabase = createAdminClient()
  await adminSupabase.schema('audit').from('staff_events').insert({
    staff_id: staffId,
    action,
    resource,
    resource_id: resourceId,
    payload
  })
}

// ---- COUNTRIES ----
export async function getCountries() {
  const { staff } = await getAuthContext()
  if (!staff || staff.role === 'BILLING_MANAGER') throw new Error('Unauthorized')
  
  const adminSupabase = createAdminClient()
  const { data, error } = await adminSupabase.rpc('rpc_get_countries')
    
  if (error) throw error
  return data || []
}

export async function createCountry(data: any) {
  const { staff } = await getAuthContext()
  if (!staff || !['PLATFORM_SUPERADMIN', 'CATALOG_MANAGER'].includes(staff.role)) throw new Error('Unauthorized')

  const adminSupabase = createAdminClient()
  const { data: record, error } = await adminSupabase.rpc('rpc_create_country', {
    p_iso2: data.iso2,
    p_iso3: data.iso3,
    p_numeric_code: data.numeric_code,
    p_official_name: data.official_name,
    p_display_name: data.display_name,
    p_default_currency_code: data.default_currency_code,
    p_staff_id: staff.id
  })
    
  if (error) throw error
  
  await logAudit(staff.id, 'CREATE', 'catalog.countries', record.id, data)
  revalidatePath('/data-hub/geography/countries')
  return record
}

export async function updateCountry(id: string, data: any) {
  const { staff } = await getAuthContext()
  if (!staff || !['PLATFORM_SUPERADMIN', 'CATALOG_MANAGER'].includes(staff.role)) throw new Error('Unauthorized')

  const adminSupabase = createAdminClient()
  const { data: record, error } = await adminSupabase.rpc('rpc_update_country', {
    p_id: id,
    p_official_name: data.official_name,
    p_display_name: data.display_name,
    p_default_currency_code: data.default_currency_code,
    p_status: data.status,
    p_staff_id: staff.id
  })
    
  if (error) throw error
  
  await logAudit(staff.id, 'UPDATE', 'catalog.countries', id, data)
  revalidatePath('/data-hub/geography/countries')
  return record
}

// ---- LEVELS ----
export async function getLevels(countryId: string) {
  if (!countryId) return []
  const { staff } = await getAuthContext()
  if (!staff || staff.role === 'BILLING_MANAGER') throw new Error('Unauthorized')
  
  const adminSupabase = createAdminClient()
  const { data, error } = await adminSupabase.rpc('rpc_get_levels', { p_country_id: countryId })
    
  if (error) throw error
  return data || []
}

export async function createLevel(data: any) {
  // To be implemented via RPC if needed
  throw new Error('Not implemented via RPC yet')
}

export async function updateLevel(id: string, countryId: string, data: any) {
  // To be implemented via RPC if needed
  throw new Error('Not implemented via RPC yet')
}
