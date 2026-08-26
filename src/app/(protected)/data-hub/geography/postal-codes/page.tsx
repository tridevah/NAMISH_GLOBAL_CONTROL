import { getAuthContext } from '@/utils/auth'
import { redirect } from 'next/navigation'

export default async function PostalCodesPage() {
  const { staff } = await getAuthContext()
  if (!staff) redirect('/login')

  return (
    <div>
      <h1 className="text-2xl font-bold tracking-tight mb-2">Postal Codes</h1>
      <p className="text-zinc-400 mb-6">Manage postal codes and map them to valid geography units.</p>
      <div className="p-12 text-center border border-dashed border-zinc-800 rounded-xl text-zinc-500">
        Postal Codes management functionality initialized. Implementation pending.
      </div>
    </div>
  )
}
