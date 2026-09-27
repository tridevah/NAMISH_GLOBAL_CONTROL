import re
filepath = r"src\app\api\s2s\master-data\units\route.ts"
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    "return NextResponse.json({ data, count, limit, offset, provider: 'global-control' });",
    "return NextResponse.json({ rows: data, total: count, limit, offset, provider: 'global-control' });"
)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated GC S2S response contract.")
