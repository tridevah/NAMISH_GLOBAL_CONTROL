'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import { usePathname, useRouter, useSearchParams } from 'next/navigation'
import { 
  Database,
  ArrowLeft,
  Percent,
  FileText,
  Tag,
  PackageCheck,
  Menu,
  User,
  LogOut,
  Globe,
  MapPin,
  Layers,
  Map,
  Mail
} from 'lucide-react'
import { createClient } from '@/utils/supabase/client'
import clsx from 'clsx'

type StaffRole = 'PLATFORM_SUPERADMIN' | 'CATALOG_MANAGER' | 'BILLING_MANAGER' | 'SUPPORT_AUDITOR'

interface DataHubShellProps {
  children: React.ReactNode
  email: string
  role: StaffRole
}

export default function DataHubShell({ children, email, role }: DataHubShellProps) {
  const [sidebarOpen, setSidebarOpen] = useState(false)
  const [countries, setCountries] = useState<any[]>([])
  const pathname = usePathname()
  const router = useRouter()
  const searchParams = useSearchParams()
  const supabase = createClient()
  
  const selectedCountry = searchParams.get('country') || ''

  useEffect(() => {
    async function fetchCountries() {
      const res = await fetch('/api/data-hub/countries')
      if (res.ok) {
        const data = await res.json()
        setCountries(data)
      }
    }
    fetchCountries()
  }, [])

  const handleLogout = async () => {
    await supabase.auth.signOut()
    router.push('/login')
    router.refresh()
  }

  const handleCountryChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    const newCountry = e.target.value
    const params = new URLSearchParams(searchParams.toString())
    if (newCountry) {
      params.set('country', newCountry)
    } else {
      params.delete('country')
    }
    router.push(pathname + '?' + params.toString())
  }

  const querySuffix = selectedCountry ? '?country=' + selectedCountry : ''

  const geoNavItems = [
    { name: 'Countries Master', href: '/data-hub/geography/countries', icon: Globe },
    { name: 'Geography Levels', href: '/data-hub/geography/levels', icon: Layers },
    { name: 'Geography Units', href: '/data-hub/geography/units', icon: Map },
    { name: 'Postal Codes', href: '/data-hub/geography/postal-codes', icon: Mail },
  ]

  const taxNavItems = [
    { name: 'Tax Overview', href: '/data-hub/tax', icon: Percent },
    { name: 'Tax Authorities', href: '/data-hub/tax/authorities', icon: Database },
    { name: 'GST Rates (India)', href: '/data-hub/tax/gst-rates', icon: Tag },
    { name: 'HSN & SAC Codes', href: '/data-hub/tax/hsn-sac', icon: PackageCheck },
  ]

  const activeCountry = countries.find(c => c.id === selectedCountry)
  const showTax = activeCountry && activeCountry.tax_coverage !== 'NOT_CONFIGURED'

  return (
    <div className="min-h-screen bg-zinc-950 text-zinc-100 flex">
      {/* Mobile sidebar backdrop */}
      {sidebarOpen && (
        <div 
          className="fixed inset-0 z-40 bg-black/80 lg:hidden"
          onClick={() => setSidebarOpen(false)}
        />
      )}

      {/* Sidebar */}
      <aside className={clsx(
        "fixed inset-y-0 left-0 z-50 w-72 bg-zinc-900 border-r border-zinc-800 transform transition-transform duration-300 lg:translate-x-0 lg:static lg:block flex flex-col",
        sidebarOpen ? "translate-x-0" : "-translate-x-full"
      )}>
        <div className="h-16 flex items-center px-6 border-b border-zinc-800 shrink-0">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded bg-teal-600 flex items-center justify-center font-bold text-white shadow-lg shadow-teal-600/20">DH</div>
            <span className="font-semibold text-lg tracking-tight">ERP Data Hub</span>
          </div>
        </div>

        <div className="flex-1 overflow-y-auto py-6 px-4">
          <Link
            href="/"
            className="flex items-center gap-2 px-3 py-2 text-sm text-zinc-400 hover:text-white mb-6 transition-colors"
          >
            <ArrowLeft className="w-4 h-4" />
            Return to Global Control
          </Link>

          <Link
            href="/data-hub"
            className={clsx(
              "flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors mb-6",
              pathname === '/data-hub'
                ? "bg-teal-500/10 text-teal-400" 
                : "text-zinc-400 hover:bg-zinc-800/50 hover:text-zinc-100"
            )}
          >
            <Database className="w-5 h-5" />
            Dashboard
          </Link>

          <div className="mb-6 px-2">
            <label className="block text-xs font-medium text-zinc-500 uppercase tracking-wider mb-2">Selected Country</label>
            <select 
              value={selectedCountry} 
              onChange={handleCountryChange}
              className="w-full bg-zinc-950 border border-zinc-800 rounded-lg px-3 py-2 text-sm focus:ring-1 focus:ring-teal-500 outline-none"
            >
              <option value="">-- Select Country --</option>
              {countries.map(c => (
                <option key={c.id} value={c.id}>{c.display_name || c.name} ({c.iso2})</option>
              ))}
            </select>
          </div>
          
          <div className="text-xs font-medium text-zinc-500 uppercase tracking-wider mb-2 px-2 mt-8">Geography</div>
          <nav className="space-y-1 mb-6">
            {geoNavItems.map((item) => {
              const isActive = pathname === item.href
              return (
                <Link
                  key={item.name}
                  href={item.href + querySuffix}
                  className={clsx(
                    "flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors",
                    isActive 
                      ? "bg-teal-500/10 text-teal-400" 
                      : "text-zinc-400 hover:bg-zinc-800/50 hover:text-zinc-100"
                  )}
                >
                  <item.icon className="w-5 h-5" />
                  {item.name}
                  </Link>
                )
              })}
            </nav>
            
            {showTax && (
              <>
                <div className="text-xs font-medium text-zinc-500 uppercase tracking-wider mb-2 px-2 mt-8">Tax & Compliance</div>
                <nav className="space-y-1 mb-6">
                  {taxNavItems.map((item) => {
                    const isActive = pathname === item.href
                    return (
                      <Link
                        key={item.name}
                        href={item.href + querySuffix}
                        className={clsx(
                          "flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors",
                          isActive 
                            ? "bg-teal-500/10 text-teal-400" 
                            : "text-zinc-400 hover:bg-zinc-800/50 hover:text-zinc-100"
                        )}
                      >
                        <item.icon className="w-5 h-5" />
                        {item.name}
                      </Link>
                    )
                  })}
                </nav>
              </>
            )}

          </div>

          <div className="p-4 border-t border-zinc-800 shrink-0">
          <div className="flex items-center gap-3 mb-4 px-2">
            <div className="w-10 h-10 rounded-full bg-zinc-800 flex items-center justify-center border border-zinc-700 shrink-0">
              <User className="w-5 h-5 text-zinc-400" />
            </div>
            <div className="min-w-0 flex-1">
              <p className="text-sm font-medium text-white truncate">{email}</p>
              <p className="text-xs text-teal-400 font-medium truncate">{role.replace('_', ' ')}</p>
            </div>
          </div>
          <button
            onClick={handleLogout}
            className="w-full flex items-center justify-center gap-2 px-4 py-2.5 rounded-lg text-sm font-medium text-zinc-400 hover:bg-red-500/10 hover:text-red-400 transition-colors"
          >
            <LogOut className="w-4 h-4" />
            Secure Logout
          </button>
        </div>
      </aside>

      {/* Main content */}
      <div className="flex-1 flex flex-col min-w-0">
        {/* Mobile header */}
        <header className="lg:hidden h-16 flex items-center justify-between px-4 border-b border-zinc-800 bg-zinc-900/50 backdrop-blur-md sticky top-0 z-30">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded bg-teal-600 flex items-center justify-center font-bold text-white">DH</div>
            <span className="font-semibold text-lg">Data Hub</span>
          </div>
          <button
            onClick={() => setSidebarOpen(true)}
            className="p-2 text-zinc-400 hover:text-white rounded-lg hover:bg-zinc-800"
          >
            <Menu className="w-6 h-6" />
          </button>
        </header>

        <main className="flex-1 overflow-y-auto p-4 lg:p-8">
          <div className="max-w-7xl mx-auto">
            {!selectedCountry && pathname !== '/data-hub' && pathname !== '/data-hub/geography/countries' ? (
              <div className="p-12 text-center border border-dashed border-zinc-800 rounded-xl bg-zinc-900/30">
                <Globe className="w-12 h-12 text-zinc-600 mx-auto mb-4" />
                <h2 className="text-lg font-medium text-white">No Country Selected</h2>
                <p className="text-zinc-400 mt-2">Please select a country from the sidebar to view its data.</p>
              </div>
            ) : (
              children
            )}
          </div>
        </main>
      </div>
    </div>
  )
}

