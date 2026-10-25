import { getAuthContext } from '@/utils/auth'
import { redirect } from 'next/navigation'
import SubDepartmentsClient from './SubDepartmentsClient'

export default async function DepartmentsPage() {
    const { staff } = await getAuthContext()
    if (!staff) redirect('/login')

    return (
        <SubDepartmentsClient />
    )
}

