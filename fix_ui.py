import re

with open('src/app/(protected)/data-hub/units/UnitsClient.tsx', 'r') as f:
    code = f.read()

replacement = """                        ) : (
                            <select
                                aria-label="UNECE category"
                                value={category}
                                onChange={(e) => { setCategory(e.target.value); setPage(1); }}
                                className="bg-white text-gray-900 border border-gray-300 rounded-md text-sm py-2 pl-3 pr-8 focus:ring-2 focus:ring-blue-500 outline-none"
                            >
                                <option value="ALL">UNECE category</option>
                                {categoryOptions.map(cat => (
                                    <option key={cat} value={cat}>{cat}</option>
                                ))}
                            </select>
                        )}
                        <select
                            value={isCommon}"""

code = code.replace(
"""                        ) : (
                            <select
                            value={isCommon}""", replacement)

with open('src/app/(protected)/data-hub/units/UnitsClient.tsx', 'w') as f:
    f.write(code)
