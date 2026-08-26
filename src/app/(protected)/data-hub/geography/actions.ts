'use server'

import { getAuthContext } from '@/utils/auth'
import { createAdminClient } from '@/utils/supabase/admin'
import { revalidatePath } from 'next/cache'

const CATALOG_ADMIN_ROLES = ['PLATFORM_SUPERADMIN', 'CATALOG_MANAGER'] as const
const READ_ROLES = ['PLATFORM_SUPERADMIN', 'CATALOG_MANAGER', 'SUPPORT_AUDITOR'] as const

async function logAudit(staffId: string, action: string, resource: string, resourceId: string | null, payload: unknown) {
  const admin = createAdminClient()
  await admin.rpc('rpc_write_audit', {
    p_staff_id: staffId,
    p_action: action,
    p_resource: resource,
    p_resource_id: resourceId,
    p_payload: payload,
  })
}

// ── COUNTRIES ─────────────────────────────────────────────

export async function getCountries() {
  const { staff } = await getAuthContext()
  if (!staff || staff.role === 'BILLING_MANAGER') throw new Error('Unauthorized')
  const admin = createAdminClient()
  const { data, error } = await admin.rpc('rpc_get_countries')
  if (error) throw error
  return (data || []) as any[]
}

export async function createCountry(data: {
  iso2: string; iso3: string; numeric_code?: string
  official_name: string; display_name: string; default_currency_code: string
}) {
  const { staff } = await getAuthContext()
  if (!staff || !CATALOG_ADMIN_ROLES.includes(staff.role)) throw new Error('Unauthorized')
  const admin = createAdminClient()
  const { data: record, error } = await admin.rpc('rpc_create_country', {
    p_iso2: data.iso2, p_iso3: data.iso3, p_numeric_code: data.numeric_code ?? null,
    p_official_name: data.official_name, p_display_name: data.display_name,
    p_default_currency_code: data.default_currency_code, p_staff_id: staff.id,
  })
  if (error) throw error
  revalidatePath('/data-hub/geography/countries')
  return record
}

export async function updateCountry(id: string, data: {
  official_name: string; display_name: string; default_currency_code: string; status: string
}) {
  const { staff } = await getAuthContext()
  if (!staff || !CATALOG_ADMIN_ROLES.includes(staff.role)) throw new Error('Unauthorized')
  const admin = createAdminClient()
  const { data: record, error } = await admin.rpc('rpc_update_country', {
    p_id: id, p_official_name: data.official_name, p_display_name: data.display_name,
    p_default_currency_code: data.default_currency_code, p_status: data.status,
    p_staff_id: staff.id,
  })
  if (error) throw error
  revalidatePath('/data-hub/geography/countries')
  return record
}

// ── GEOGRAPHY LEVELS ──────────────────────────────────────

export async function getLevels(countryId: string) {
  if (!countryId) return []
  const { staff } = await getAuthContext()
  if (!staff || staff.role === 'BILLING_MANAGER') throw new Error('Unauthorized')
  const admin = createAdminClient()
  const { data, error } = await admin.rpc('rpc_get_levels', { p_country_id: countryId })
  if (error) throw error
  return (data || []) as any[]
}

export async function createLevel(data: {
  country_id: string; level_number: number; level_key: string; display_label: string
}) {
  const { staff } = await getAuthContext()
  if (!staff || !CATALOG_ADMIN_ROLES.includes(staff.role)) throw new Error('Unauthorized')
  const admin = createAdminClient()
  const { data: record, error } = await admin.rpc('rpc_create_level', {
    p_country_id: data.country_id, p_level_number: data.level_number,
    p_level_key: data.level_key, p_display_label: data.display_label,
    p_staff_id: staff.id,
  })
  if (error) throw error
  revalidatePath('/data-hub/geography/levels')
  return record
}

export async function updateLevel(id: string, data: { display_label: string; status: string }) {
  const { staff } = await getAuthContext()
  if (!staff || !CATALOG_ADMIN_ROLES.includes(staff.role)) throw new Error('Unauthorized')
  const admin = createAdminClient()
  const { data: record, error } = await admin.rpc('rpc_update_level', {
    p_id: id, p_display_label: data.display_label, p_status: data.status,
    p_staff_id: staff.id,
  })
  if (error) throw error
  revalidatePath('/data-hub/geography/levels')
  return record
}

// ── GEOGRAPHY UNITS ───────────────────────────────────────

export async function getUnits(opts: {
  country_id: string; level_id?: string; parent_id?: string
  status?: string; search?: string; limit?: number; offset?: number
}) {
  const { staff } = await getAuthContext()
  if (!staff || staff.role === 'BILLING_MANAGER') throw new Error('Unauthorized')
  const admin = createAdminClient()
  const { data, error } = await admin.rpc('rpc_get_units', {
    p_country_id: opts.country_id,
    p_level_id: opts.level_id ?? null,
    p_parent_id: opts.parent_id ?? null,
    p_status: opts.status ?? null,
    p_search: opts.search ?? null,
    p_limit: opts.limit ?? 200,
    p_offset: opts.offset ?? 0,
  })
  if (error) throw error
  return (data as any) || { rows: [], total: 0 }
}

export async function createUnit(data: {
  country_id: string; geography_level_id: string; parent_geography_unit_id?: string
  official_code: string; iso_subdivision_code?: string; official_name: string; display_name: string
}) {
  const { staff } = await getAuthContext()
  if (!staff || !CATALOG_ADMIN_ROLES.includes(staff.role)) throw new Error('Unauthorized')
  const admin = createAdminClient()
  const { data: record, error } = await admin.rpc('rpc_create_unit', {
    p_country_id: data.country_id,
    p_geography_level_id: data.geography_level_id,
    p_parent_geography_unit_id: data.parent_geography_unit_id ?? null,
    p_official_code: data.official_code,
    p_iso_subdivision_code: data.iso_subdivision_code ?? '',
    p_official_name: data.official_name,
    p_display_name: data.display_name,
    p_staff_id: staff.id,
  })
  if (error) throw error
  revalidatePath('/data-hub/geography/units')
  return record
}

export async function updateUnit(id: string, data: {
  official_name: string; display_name: string; iso_subdivision_code?: string; status: string
}) {
  const { staff } = await getAuthContext()
  if (!staff || !CATALOG_ADMIN_ROLES.includes(staff.role)) throw new Error('Unauthorized')
  const admin = createAdminClient()
  const { data: record, error } = await admin.rpc('rpc_update_unit', {
    p_id: id, p_official_name: data.official_name, p_display_name: data.display_name,
    p_iso_subdivision_code: data.iso_subdivision_code ?? '',
    p_status: data.status, p_staff_id: staff.id,
  })
  if (error) throw error
  revalidatePath('/data-hub/geography/units')
  return record
}

// ── POSTAL CODES ──────────────────────────────────────────

export async function getPostalCodes(opts: {
  country_id: string; status?: string; search?: string; limit?: number; offset?: number
}) {
  const { staff } = await getAuthContext()
  if (!staff || staff.role === 'BILLING_MANAGER') throw new Error('Unauthorized')
  const admin = createAdminClient()
  const { data, error } = await admin.rpc('rpc_get_postal_codes', {
    p_country_id: opts.country_id,
    p_status: opts.status ?? null,
    p_search: opts.search ?? null,
    p_limit: opts.limit ?? 100,
    p_offset: opts.offset ?? 0,
  })
  if (error) throw error
  return (data as any) || { rows: [], total: 0 }
}

export async function createPostalCode(data: { country_id: string; postal_code: string }) {
  const { staff } = await getAuthContext()
  if (!staff || !CATALOG_ADMIN_ROLES.includes(staff.role)) throw new Error('Unauthorized')
  const admin = createAdminClient()
  const { data: record, error } = await admin.rpc('rpc_create_postal_code', {
    p_country_id: data.country_id, p_postal_code: data.postal_code, p_staff_id: staff.id,
  })
  if (error) throw error
  revalidatePath('/data-hub/geography/postal-codes')
  return record
}

export async function updatePostalCode(id: string, data: { postal_code: string; status: string }) {
  const { staff } = await getAuthContext()
  if (!staff || !CATALOG_ADMIN_ROLES.includes(staff.role)) throw new Error('Unauthorized')
  const admin = createAdminClient()
  const { data: record, error } = await admin.rpc('rpc_update_postal_code', {
    p_id: id, p_postal_code: data.postal_code, p_status: data.status, p_staff_id: staff.id,
  })
  if (error) throw error
  revalidatePath('/data-hub/geography/postal-codes')
  return record
}

export async function setPostalMappings(postalCodeId: string, geographyUnitIds: string[]) {
  const { staff } = await getAuthContext()
  if (!staff || !CATALOG_ADMIN_ROLES.includes(staff.role)) throw new Error('Unauthorized')
  const admin = createAdminClient()
  const { error } = await admin.rpc('rpc_set_postal_mappings', {
    p_postal_code_id: postalCodeId,
    p_geography_unit_ids: geographyUnitIds,
    p_staff_id: staff.id,
  })
  if (error) throw error
  revalidatePath('/data-hub/geography/postal-codes')
}
