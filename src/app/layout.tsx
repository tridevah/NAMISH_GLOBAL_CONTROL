
import './globals.css'
import Link from 'next/link'

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <div className="flex h-screen bg-gray-100 text-gray-900">
          <aside className="w-64 bg-white border-r">
            <div className="p-4 text-lg font-bold">NAMISH Global Control</div>
            <nav className="p-4 flex flex-col gap-2">
              <Link href="/">Dashboard</Link>
              <Link href="/catalog">Catalog</Link>
              <Link href="/billing">Billing</Link>
              <Link href="/tenant-registry">Tenant Registry</Link>
              <Link href="/audit">Audit</Link>
            </nav>
          </aside>
          <main className="flex-1 p-8 overflow-auto">
            {children}
          </main>
        </div>
      </body>
    </html>
  )
}
