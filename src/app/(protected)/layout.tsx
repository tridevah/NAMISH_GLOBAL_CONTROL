import { redirect } from 'next/navigation'
import { getAuthContext } from '@/utils/auth'
import { createClient } from '@/utils/supabase/server'

export default async function ProtectedLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const { user, staff, error } = await getAuthContext()

  if (error === 'NO_USER') {
    redirect('/login')
  }

  if (error === 'UNAUTHORIZED' || !staff) {
    const supabase = await createClient()
    await supabase.auth.signOut()
    redirect('/login?error=Unauthorized%20access.%20Your%20account%20may%20lack%20platform%20permissions%20or%20is%20inactive.')
  }

  return <>{children}</>
}
