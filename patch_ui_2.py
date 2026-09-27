import re

with open('src/app/(protected)/data-hub/units/UnitsClient.tsx', 'r') as f:
    code = f.read()

# Add handleToggleBusiness function inside UnitsClient
handle_toggle_func = """
    const handleToggleBusiness = async (unit: any) => {
        try {
            const res = await fetch('/api/data-hub/units', {
                method: 'PATCH',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ id: unit.id, is_common: !unit.is_common })
            })
            if (!res.ok) throw new Error('Update failed')
            
            // Update local state
            setUnits(units.map(u => u.id === unit.id ? { ...u, is_common: !u.is_common } : u))
        } catch (e) {
            console.error(e)
            alert('Failed to update business unit designation.')
        }
    }
"""

# Insert before return (
code = code.replace("    return (", handle_toggle_func + "\n    return (")

# Update table head
table_head = """
                                <th className="px-6 py-3 font-medium text-right">Status</th>
                                <th className="px-6 py-3 font-medium text-right">Actions</th>
"""
code = code.replace('<th className="px-6 py-3 font-medium text-right">Status</th>', table_head)

# Update table row
table_row = """
                                        <td className="px-6 py-4 text-right">
                                            <span className={"inline-flex items-center px-2 py-0.5 rounded text-xs font-medium " + (u.status === 'ACTIVE' ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800')}>
                                                {u.status}
                                            </span>
                                        </td>
                                        <td className="px-6 py-4 text-right">
                                            <button 
                                                onClick={() => handleToggleBusiness(u)}
                                                className={`text-xs font-medium px-3 py-1 rounded border ${u.is_common ? 'bg-blue-50 text-blue-700 border-blue-200 hover:bg-blue-100' : 'bg-white text-gray-600 border-gray-300 hover:bg-gray-50'}`}
                                            >
                                                {u.is_common ? 'Remove Business Unit' : 'Make Business Unit'}
                                            </button>
                                        </td>
"""
code = re.sub(
    r"<td className=\"px-6 py-4 text-right\">[\s\S]*?</td>",
    table_row.strip(),
    code,
    count=1
)

with open('src/app/(protected)/data-hub/units/UnitsClient.tsx', 'w') as f:
    f.write(code)
