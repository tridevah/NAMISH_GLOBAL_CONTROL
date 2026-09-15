import { getAuthContext } from '@/utils/auth'
import { createAdminClient } from '@/utils/supabase/admin'
import { redirect } from 'next/navigation'
import Link from 'next/link'
import { ChevronLeft, ChevronRight, Search, Filter } from 'lucide-react'

type Account = {
  id: string
  name: string
  status: string
  created_at: string
  has_erp_binding: boolean
}

type PageProps = {
  searchParams?: Promise<{ [key: string]: string | string[] | undefined }>
}

const isValidDate = (dateStr: string | null | undefined) => {
  if (!dateStr) return false
  const d = new Date(dateStr)
  return !isNaN(d.getTime()) && d.getTime() > 0
}

const isValidUUID = (uuid: string | null | undefined) => {
  if (!uuid || typeof uuid !== 'string') return false
  const regex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
  return regex.test(uuid)
}

export default async function AccountsPage({ searchParams }: PageProps) {
  const { staff, error: authError } = await getAuthContext()

  if (authError || !staff || staff.status !== 'ACTIVE') {
    redirect('/login')
  }

  const allowedRoles = ['PLATFORM_SUPERADMIN', 'SUPPORT_AUDITOR']
  if (!allowedRoles.includes(staff.role)) {
    redirect('/')
  }

  const resolvedParams = searchParams ? await searchParams : {}
  const pageParam = resolvedParams.page
  const searchParam = resolvedParams.search
  const statusParam = resolvedParams.status
  
  let requestedPage = 1
  if (typeof pageParam === 'string') {
    if (!/^[1-9]\d*$/.test(pageParam)) {
      return (
        <div className="p-12 text-center text-red-400 bg-zinc-900 border border-zinc-800 rounded-xl">
          Invalid pagination parameters. Must be a positive integer string.
        </div>
      )
    }
    const parsed = parseInt(pageParam, 10)
    if (parsed > 2147483647) {
      return (
        <div className="p-12 text-center text-red-400 bg-zinc-900 border border-zinc-800 rounded-xl">
          Pagination exceeds integer limits.
        </div>
      )
    }
    requestedPage = parsed
  }

  const searchQuery = typeof searchParam === 'string' ? searchParam : ''
  const statusQuery = typeof statusParam === 'string' ? statusParam : ''
  const requestPageSize = 50

  let adminSupabase: ReturnType<typeof createAdminClient>
  try {
    adminSupabase = createAdminClient()
  } catch (err) {
    return (
      <div className="p-12 text-center text-red-400 bg-zinc-900 border border-zinc-800 rounded-xl">
        Failed to initialize directory client.
      </div>
    )
  }

  let rawData = null
  let rpcError = null

  try {
    const { data, error } = await adminSupabase.rpc('rpc_search_platform_accounts', {
      p_search: searchQuery || null,
      p_status: statusQuery || null,
      p_page: requestedPage,
      p_page_size: requestPageSize
    })
    rawData = data
    rpcError = error
  } catch (err) {
    rpcError = err
  }

  let result = rawData
  if (typeof rawData === 'string') {
    try {
      result = JSON.parse(rawData)
    } catch (e) {
      result = null
    }
  }

  let items: Account[] = []
  let isError = !!rpcError || !result
  let serverPage = requestedPage
  let serverPageSize = requestPageSize
  let serverTotal = 0
  
  if (!isError && result) {
    if (typeof result.total === 'number' && Number.isSafeInteger(result.total) && result.total >= 0) {
      serverTotal = result.total
    } else {
      isError = true
    }

    if (typeof result.page === 'number' && Number.isSafeInteger(result.page) && result.page >= 1) {
      serverPage = result.page
    } else {
      isError = true
    }

    if (typeof result.page_size === 'number' && Number.isSafeInteger(result.page_size) && result.page_size >= 1) {
      serverPageSize = result.page_size
    } else {
      isError = true
    }
    
    if (Array.isArray(result.items) && !isError) {
      const offset = (serverPage - 1) * serverPageSize;
      const expectedLen = Math.min(serverPageSize, Math.max(0, serverTotal - offset));
      
      if (result.items.length !== expectedLen) {
        isError = true
      } else {
        const allValid = result.items.every((item: any) => {
          if (!item || typeof item !== 'object') return false
          if (!isValidUUID(item.id)) return false
          if (typeof item.name !== 'string' && item.name !== null) return false
          if (typeof item.status !== 'string' && item.status !== null) return false
          if (item.created_at !== null && !isValidDate(item.created_at)) return false
          if (typeof item.has_erp_binding !== 'boolean') return false
          return true
        })
        if (!allValid) {
          isError = true
        } else {
          items = result.items
        }
      }
    } else {
      isError = true
    }
  }

  const totalPages = Math.max(1, Math.ceil(serverTotal / serverPageSize))
  const isOutOfRange = serverPage > totalPages && serverTotal > 0

  const formatDate = (dateStr: string | null | undefined) => {
    if (!dateStr) return 'Unknown'
    const date = new Date(dateStr)
    if (isNaN(date.getTime()) || date.getTime() <= 0) return 'Unknown'
    return date.toLocaleDateString()
  }
  
  const buildQueryString = (page: number) => {
    const params = new URLSearchParams()
    if (page > 1) params.set('page', page.toString())
    if (searchQuery) params.set('search', searchQuery)
    if (statusQuery) params.set('status', statusQuery)
    const str = params.toString()
    return str ? `?${str}` : ''
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight text-white">Enterprise Accounts</h1>
        <p className="text-zinc-400 mt-1 text-sm">
          Registered enterprise accounts.
          {!isError && (
            <span className="ml-2 text-zinc-500">({serverTotal.toLocaleString()} total)</span>
          )}
        </p>
      </div>

      <div className="bg-zinc-900 border border-zinc-800 rounded-xl overflow-hidden flex flex-col">
        <div className="p-4 border-b border-zinc-800 bg-zinc-900/50 flex flex-col sm:flex-row gap-4 items-center justify-between">
          <form className="flex-1 w-full flex gap-3" method="GET" action="/accounts">
            <div className="relative flex-1 max-w-md">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-400" />
              <input 
                type="text" 
                name="search" 
                defaultValue={searchQuery}
                placeholder="Search by name or ID..." 
                className="w-full pl-9 pr-4 py-2 bg-zinc-950 border border-zinc-800 rounded-lg text-sm text-white placeholder:text-zinc-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
              />
            </div>
            <div className="relative">
              <Filter className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-400" />
              <select 
                name="status" 
                defaultValue={statusQuery}
                className="pl-9 pr-8 py-2 bg-zinc-950 border border-zinc-800 rounded-lg text-sm text-white focus:outline-none focus:ring-1 focus:ring-indigo-500 appearance-none"
              >
                <option value="">All Statuses</option>
                <option value="ACTIVE">ACTIVE</option>
                <option value="SUSPENDED">SUSPENDED</option>
                <option value="PENDING">PENDING</option>
              </select>
            </div>
            <button type="submit" className="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white text-sm font-medium rounded-lg transition-colors">
              Search
            </button>
            {(searchQuery || statusQuery) && (
              <Link href="/accounts" className="px-4 py-2 bg-zinc-800 hover:bg-zinc-700 text-white text-sm font-medium rounded-lg transition-colors flex items-center">
                Clear
              </Link>
            )}
          </form>
        </div>

        <div className="overflow-x-auto min-h-[400px]">
          {isError ? (
            <div className="p-12 text-center">
              <div className="inline-flex items-center justify-center w-12 h-12 rounded-full bg-red-500/10 mb-4">
                <span className="text-red-400 text-xl">!</span>
              </div>
              <h3 className="text-lg font-medium text-white">Failed to load accounts</h3>
              <p className="text-zinc-400 mt-1">There was an error communicating with the directory service or parsing the response.</p>
            </div>
          ) : isOutOfRange ? (
            <div className="p-12 text-center">
              <h3 className="text-lg font-medium text-white">Page not found</h3>
              <p className="text-zinc-400 mt-1">The requested page exceeds the available results.</p>
              <Link href={`/accounts${buildQueryString(totalPages)}`} className="inline-block mt-4 text-indigo-400 hover:text-indigo-300">
                Go to last page
              </Link>
            </div>
          ) : items.length === 0 ? (
            <div className="p-12 text-center">
              <h3 className="text-lg font-medium text-white">No enterprise accounts found</h3>
              <p className="text-zinc-400 mt-1">
                {(searchQuery || statusQuery) ? 'Try adjusting your search filters.' : 'There are currently no registered enterprise accounts.'}
              </p>
            </div>
          ) : (
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="border-b border-zinc-800 bg-zinc-900/50">
                  <th className="py-3 px-4 text-xs font-semibold text-zinc-400 uppercase tracking-wider">Account</th>
                  <th className="py-3 px-4 text-xs font-semibold text-zinc-400 uppercase tracking-wider">ID</th>
                  <th className="py-3 px-4 text-xs font-semibold text-zinc-400 uppercase tracking-wider">Status</th>
                  <th className="py-3 px-4 text-xs font-semibold text-zinc-400 uppercase tracking-wider">ERP Binding</th>
                  <th className="py-3 px-4 text-xs font-semibold text-zinc-400 uppercase tracking-wider">Created</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-zinc-800">
                {items.map((account) => (
                  <tr key={account.id} className="hover:bg-zinc-800/50 transition-colors group">
                    <td className="py-3 px-4">
                      <Link href={`/accounts/${account.id}`} className="block">
                        <span className="text-sm font-medium text-white group-hover:text-indigo-400 transition-colors">{account.name || 'Unknown'}</span>
                      </Link>
                    </td>
                    <td className="py-3 px-4 text-sm text-zinc-400 font-mono">
                      {account.id ? account.id.split('-')[0] + '...' : 'Unknown'}
                    </td>
                    <td className="py-3 px-4">
                      <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium border ${
                        account.status === 'ACTIVE' ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20' : 
                        'bg-zinc-500/10 text-zinc-400 border-zinc-500/20'
                      }`}>
                        {account.status || 'UNKNOWN'}
                      </span>
                    </td>
                    <td className="py-3 px-4">
                      {account.has_erp_binding === true ? (
                        <span className="text-sm text-zinc-300 flex items-center gap-1">
                          <span className="w-1.5 h-1.5 rounded-full bg-emerald-500"></span>
                          BOUND
                        </span>
                      ) : (
                        <span className="text-sm text-zinc-500">UNBOUND</span>
                      )}
                    </td>
                    <td className="py-3 px-4 text-sm text-zinc-400">
                      {formatDate(account.created_at)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>

        {!isError && !isOutOfRange && serverTotal > 0 && (
          <div className="p-4 border-t border-zinc-800 bg-zinc-900/50 flex items-center justify-between">
            <p className="text-sm text-zinc-400">
              Showing <span className="font-medium text-white">{((serverPage - 1) * serverPageSize) + 1}</span> to{' '}
              <span className="font-medium text-white">{Math.min(serverPage * serverPageSize, serverTotal)}</span> of{' '}
              <span className="font-medium text-white">{serverTotal}</span> results
            </p>
            <div className="flex gap-2">
              {serverPage > 1 ? (
                <Link 
                  href={`/accounts${buildQueryString(serverPage - 1)}`}
                  className="px-3 py-1 bg-zinc-800 hover:bg-zinc-700 text-white text-sm font-medium rounded transition-colors flex items-center gap-1"
                >
                  <ChevronLeft className="w-4 h-4" /> Previous
                </Link>
              ) : (
                <span className="px-3 py-1 bg-zinc-900 text-zinc-600 text-sm font-medium rounded border border-zinc-800 cursor-not-allowed flex items-center gap-1">
                  <ChevronLeft className="w-4 h-4" /> Previous
                </span>
              )}
              
              {serverPage < totalPages ? (
                <Link 
                  href={`/accounts${buildQueryString(serverPage + 1)}`}
                  className="px-3 py-1 bg-zinc-800 hover:bg-zinc-700 text-white text-sm font-medium rounded transition-colors flex items-center gap-1"
                >
                  Next <ChevronRight className="w-4 h-4" />
                </Link>
              ) : (
                <span className="px-3 py-1 bg-zinc-900 text-zinc-600 text-sm font-medium rounded border border-zinc-800 cursor-not-allowed flex items-center gap-1">
                  Next <ChevronRight className="w-4 h-4" />
                </span>
              )}
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
