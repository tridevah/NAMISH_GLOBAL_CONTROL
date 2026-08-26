import { getAuthContext } from '@/utils/auth'
import AppShell from '@/components/layout/AppShell'

export default async function GlobalControlLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const { user, staff } = await getAuthContext()
  
  if (!user || !staff) {
    return null
  }

  return (
    <AppShell email={user.email!} role={staff.role}>
      {children}
    </AppShell>
  )
}
