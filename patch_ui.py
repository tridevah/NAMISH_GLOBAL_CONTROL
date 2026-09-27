import re

with open('src/app/(protected)/data-hub/units/UnitsClient.tsx', 'r') as f:
    code = f.read()

# Add isCommon state
code = re.sub(
    r"const \[status, setStatus\] = useState\('ALL'\)",
    "const [status, setStatus] = useState('ALL')\n    const [isCommon, setIsCommon] = useState('ALL')",
    code
)

# Add is_common to fetch params
code = re.sub(
    r"if \(status !== 'ALL'\) params.set\('status', status\)",
    "if (status !== 'ALL') params.set('status', status)\n                if (isCommon === 'true') params.set('is_common', 'true')",
    code
)

# Add dependencies to useEffect
code = re.sub(
    r"\}, \[page, search, category, status\]\)",
    "}, [page, search, category, status, isCommon])",
    code
)

# Modify search placeholder
code = re.sub(
    r"placeholder=\"Search by name, code or symbol\.\.\.\"",
    'placeholder="Search by name, short name, aliases or code..."',
    code
)

# Add clear filters and isCommon select
filters_replacement = """
                        <select
                            value={isCommon}
                            onChange={(e) => { setIsCommon(e.target.value); setPage(1); }}
                            className="bg-white text-gray-900 border border-gray-300 rounded-md text-sm py-2 pl-3 pr-8 focus:ring-2 focus:ring-blue-500 outline-none"
                        >
                            <option value="ALL">All Units</option>
                            <option value="true">Common Units</option>
                        </select>
                        <select
                            value={status}
                            onChange={(e) => { setStatus(e.target.value); setPage(1); }}
                            className="bg-white text-gray-900 border border-gray-300 rounded-md text-sm py-2 pl-3 pr-8 focus:ring-2 focus:ring-blue-500 outline-none"
                        >
                            <option value="ALL">All Status</option>
                            <option value="ACTIVE">Active</option>
                            <option value="INACTIVE">Inactive</option>
                        </select>
                        <button
                            onClick={() => { setSearch(''); setCategory('ALL'); setStatus('ALL'); setIsCommon('ALL'); setPage(1); }}
                            className="text-sm font-medium text-gray-600 hover:text-gray-900 px-2 py-2 border border-transparent"
                        >
                            Clear Filters
                        </button>
"""

code = re.sub(
    r"<select[\s\S]*?value=\{status\}[\s\S]*?</select>",
    filters_replacement.strip(),
    code
)

# Modify table rows
table_head = """
                                <th className="px-6 py-3 font-medium">Business Name</th>
                                <th className="px-6 py-3 font-medium">Short / Symbol</th>
                                <th className="px-6 py-3 font-medium">Standard Code</th>
                                <th className="px-6 py-3 font-medium">Technical Source</th>
                                <th className="px-6 py-3 font-medium text-right">Status</th>
"""

code = re.sub(
    r"<th className=\"px-6 py-3 font-medium\">Name & Symbol</th>[\s\S]*?<th className=\"px-6 py-3 font-medium text-right\">Status</th>",
    table_head.strip(),
    code
)

table_row = """
                                        <td className="px-6 py-4">
                                            <div className="font-medium text-gray-900 uppercase">{u.business_name || u.name}</div>
                                            <div className="text-gray-500 text-xs">Official: {u.name}</div>
                                        </td>
                                        <td className="px-6 py-4">
                                            <div className="text-gray-900">{u.short_name || '-'}</div>
                                            <div className="text-gray-500 text-xs">{u.symbol ? `Symbol: ${u.symbol}` : ''}</div>
                                        </td>
                                        <td className="px-6 py-4">
                                            <div className="text-gray-900 font-medium">{u.standard_code}</div>
                                            <div className="text-gray-500 text-xs">{u.canonical_code}</div>
                                        </td>
                                        <td className="px-6 py-4">
                                            <div className="text-gray-900 text-xs">{u.source} / {u.category}</div>
                                            <div className="text-gray-500 text-xs">{u.source_version}</div>
                                        </td>
"""

code = re.sub(
    r"<td className=\"px-6 py-4\">\s*<div className=\"font-medium text-gray-900 uppercase\">\{u\.name\}</div>[\s\S]*?<div className=\"text-gray-500 text-xs\">\{u\.source_version\}</div>\s*</td>",
    table_row.strip(),
    code
)

with open('src/app/(protected)/data-hub/units/UnitsClient.tsx', 'w') as f:
    f.write(code)
