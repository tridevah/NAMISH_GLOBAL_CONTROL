const fs = require('fs');
const path = require('path');
const base = 'src/app/(protected)/data-hub/tax';
const pages = ['coverage', 'regimes', 'components', 'component-sets', 'codes', 'hsn-sac', 'assignments'];

for (const p of pages) {
  const dir = path.join(base, p);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  const file = path.join(dir, 'page.tsx');
  if (!fs.existsSync(file)) {
    fs.writeFileSync(file, `
import { getAuthContext } from '@/utils/auth'
import { redirect } from 'next/navigation'

export default async function Page() {
  const { staff } = await getAuthContext()
  if (!staff) redirect('/login')

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight mb-2 text-white">Tax Data: ${p.replace('-', ' ')}</h1>
        <p className="text-zinc-400 mb-6">Placeholder for ${p} management.</p>
      </div>
      <div className="p-12 text-center border border-dashed border-zinc-800 rounded-xl bg-zinc-900/30">
        <p className="text-zinc-400">UI Module in development.</p>
      </div>
    </div>
  )
}
`.trim());
  }
}
console.log('Created missing tax pages.');
