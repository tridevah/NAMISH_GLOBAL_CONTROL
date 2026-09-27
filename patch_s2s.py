import re

filepath = 'src/app/api/s2s/master-data/units/route.ts'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Add is_business parameter extraction
if "const isBusiness = searchParams.get('is_business');" not in content:
    content = content.replace(
        "const status = searchParams.get('status');",
        "const status = searchParams.get('status');\n        const isBusiness = searchParams.get('is_business');"
    )

# Add is_business query filter
if "if (isBusiness === 'true') {" not in content:
    content = content.replace(
        "if (status && status !== 'ALL') {\n                q = q.eq('status', status);\n            }",
        "if (status && status !== 'ALL') {\n                q = q.eq('status', status);\n            }\n            if (isBusiness === 'true' && selectCols.includes('is_business')) {\n                q = q.eq('is_business', true);\n            }"
    )

# Fix S2S search to use aliases_text
if "aliases_text.ilike" not in content:
    content = content.replace(
        "q = q.or(`name.ilike.%${search}%,canonical_code.ilike.%${search}%,standard_code.ilike.%${search}%,symbol.ilike.%${search}%,business_name.ilike.%${search}%,short_name.ilike.%${search}%`);",
        "q = q.or(`name.ilike.%${search}%,canonical_code.ilike.%${search}%,standard_code.ilike.%${search}%,symbol.ilike.%${search}%,business_name.ilike.%${search}%,short_name.ilike.%${search}%,aliases_text.ilike.%${search}%`);"
    )

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated GC S2S endpoint successfully.")
