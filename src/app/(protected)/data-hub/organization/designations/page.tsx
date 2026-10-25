import { getAuthContext } from '@/utils/auth'
import { redirect } from 'next/navigation'
import DesignationsClient from './DesignationsClient'

export default async function DesignationsPage() {
    const { staff } = await getAuthContext()
    if (!staff) redirect('/login')

    return (
        <DesignationsClient />
    )
}
