'use client'

import { useState } from 'react'
import Link from 'next/link'
import { usePathname, useRouter } from 'next/navigation'
import { 
  LayoutDashboard, 
  CreditCard, 
  Building2, 
  ShieldCheck,
  LogOut,
  Menu,
  Database,
  User
} from 'lucide-react'
import { createClient } from '@/utils/supabase/client'
import clsx from 'clsx'

type StaffRole = 'PLATFORM_SUPERADMIN' | 'CATALOG_MANAGER' | 'BILLING_MANAGER' | 'SUPPORT_AUDITOR'

interface AppShellProps {
  children: React.ReactNode
  email: string
  role: StaffRole
}

export default function AppShell({ children, email, role }: AppShellProps) {
  const [sidebarOpen, setSidebarOpen] = useState(false)
  const pathname = usePathname()
  const router = useRouter()
  const supabase = createClient()

  const handleLogout = async () => {
    await supabase.auth.signOut()
    router.push('/login')
    router.refresh()
  }

  const navItems = [
    { name: 'Dashboard', href: '/', icon: LayoutDashboard, roles: ['PLATFORM_SUPERADMIN', 'CATALOG_MANAGER', 'BILLING_MANAGER', 'SUPPORT_AUDITOR'] },
    { name: 'Billing', href: '/billing', icon: CreditCard, roles: ['PLATFORM_SUPERADMIN', 'BILLING_MANAGER'] },
    { name: 'Tenant Registry', href: '/tenant-registry', icon: Building2, roles: ['PLATFORM_SUPERADMIN', 'SUPPORT_AUDITOR'] },
    { name: 'Audit', href: '/audit', icon: ShieldCheck, roles: ['PLATFORM_SUPERADMIN', 'SUPPORT_AUDITOR'] },
  ]
  
  const externalPortals = [
    { name: 'ERP Data Hub', href: '/data-hub', icon: Database, roles: ['PLATFORM_SUPERADMIN', 'CATALOG_MANAGER', 'SUPPORT_AUDITOR'] },
  ]

  const visibleNavItems = navItems.filter(item => item.roles.includes(role))
  const visibleExternalPortals = externalPortals.filter(item => item.roles.includes(role))

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
        <div className="h-16 flex items-center px-6 border-b border-zinc-800">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded bg-indigo-600 flex items-center justify-center font-bold text-white shadow-lg shadow-indigo-600/20">N</div>
            <span className="font-semibold text-lg tracking-tight">NAMISH</span>
            <span className="px-2 py-0.5 rounded-full bg-zinc-800 text-xs font-medium text-zinc-400 border border-zinc-700">CORE</span>
          </div>
        </div>

        <div className="flex-1 overflow-y-auto py-6 px-4">
          <div className="text-xs font-medium text-zinc-500 uppercase tracking-wider mb-4 px-2">Global Control</div>
          <nav className="space-y-1 mb-8">
            {visibleNavItems.map((item) => {
              const isActive = pathname === item.href || (item.href !== '/' && pathname.startsWith(item.href))
              return (
                <Link
                  key={item.name}
                  href={item.href}
                  className={clsx(
                    "flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors",
                    isActive 
                      ? "bg-indigo-500/10 text-indigo-400" 
                      : "text-zinc-400 hover:bg-zinc-800/50 hover:text-zinc-100"
                  )}
                >
                  <item.icon className="w-5 h-5" />
                  {item.name}
                </Link>
              )
            })}
          </nav>
          
          {visibleExternalPortals.length > 0 && (
            <>
              <div className="text-xs font-medium text-zinc-500 uppercase tracking-wider mb-4 px-2">External Portals</div>
              <nav className="space-y-1">
                {visibleExternalPortals.map((item) => {
                  return (
                    <Link
                      key={item.name}
                      href={item.href}
                      className="flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium text-zinc-400 hover:bg-zinc-800/50 hover:text-zinc-100 transition-colors"
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

        <div className="p-4 border-t border-zinc-800">
          <div className="flex items-center gap-3 mb-4 px-2">
            <div className="w-10 h-10 rounded-full bg-zinc-800 flex items-center justify-center border border-zinc-700 shrink-0">
              <User className="w-5 h-5 text-zinc-400" />
            </div>
            <div className="min-w-0 flex-1">
              <p className="text-sm font-medium text-white truncate">{email}</p>
              <p className="text-xs text-indigo-400 font-medium truncate">{role.replace('_', ' ')}</p>
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
            <div className="w-8 h-8 rounded bg-indigo-600 flex items-center justify-center font-bold text-white">N</div>
            <span className="font-semibold text-lg">NAMISH</span>
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
            {children}
          </div>
        </main>
      </div>
    </div>
  )
}
