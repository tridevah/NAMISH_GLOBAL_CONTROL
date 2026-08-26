import { getAuthContext } from '@/utils/auth'
import DataHubShell from '@/components/layout/DataHubShell'
import { redirect } from 'next/navigation'

export default async function DataHubLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const { user, staff } = await getAuthContext()
  
  if (!user || !staff) {
    return null
  }

  // Enforce Data Hub role matrix
  if (staff.role === 'BILLING_MANAGER') {
    redirect('/?error=Unauthorized%20for%20ERP%20Data%20Hub')
  }

  return (
    <DataHubShell email={user.email!} role={staff.role}>
      {children}
    </DataHubShell>
  )
}
