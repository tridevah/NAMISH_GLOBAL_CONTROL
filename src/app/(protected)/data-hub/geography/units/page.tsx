import { getAuthContext } from '@/utils/auth'
import { redirect } from 'next/navigation'

export default async function UnitsPage() {
  const { staff } = await getAuthContext()
  if (!staff) redirect('/login')

  return (
    <div>
      <h1 className="text-2xl font-bold tracking-tight mb-2">Geography Units</h1>
      <p className="text-zinc-400 mb-6">Manage specific geography units and hierarchy mapping.</p>
      <div className="p-12 text-center border border-dashed border-zinc-800 rounded-xl text-zinc-500">
        Geography Units management functionality initialized. Implementation pending.
      </div>
    </div>
  )
}
