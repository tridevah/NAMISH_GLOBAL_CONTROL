import re
filepath = r"src\app\api\s2s\master-data\units\route.ts"
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    "} catch (e) {\n            return NextResponse.json({ error: \"Unauthorized\" }, { status: 401 });",
    "} catch (e) {\n            console.error('JWT Verify Error:', e);\n            return NextResponse.json({ error: \"Unauthorized\" }, { status: 401 });"
)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print("Added logging")
