import { getAuthContext } from '@/utils/auth'
import { redirect } from 'next/navigation'
import UnitsClient from './UnitsClient'

export default async function UnitsPage() {
    const { staff } = await getAuthContext()
    if (!staff) redirect('/login')

    // Since the actual business units are fetched via API with fallback logic,
    // we start empty to prevent flickering technical units on first render.
    return (
        <UnitsClient
            initialUnits={[]}
            initialTotal={0}
        />
    )
}
