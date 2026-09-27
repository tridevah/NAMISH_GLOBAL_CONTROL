import os
import re

files_to_patch = set()
with open('tsc_errors.log', 'r') as f:
    for line in f:
        m = re.match(r'^([\w\.\/\-_]+)\(\d+,\d+\):', line)
        if m:
            files_to_patch.add(m.group(1))

for file in files_to_patch:
    try:
        with open(file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # fix Request missing properties
        content = re.sub(r'(\{\s*headers:\s*\{\s*get:\s*\(\)\s*=>\s*[^}]+\}\s*\})', r'(\1 as unknown as Request)', content)
        content = re.sub(r'(\{\s*apikey:[^\}]+\})', r'(\1 as unknown as RequestInit)', content)
        content = re.sub(r'(\{\s*apikey:[^\}]+\'Content-Type\':[^\}]+\})', r'(\1 as unknown as RequestInit)', content)
        
        # fix implicit any
        content = re.sub(r'(function\s+\w+)\(name, fn\)', r'\1(name: string, fn: Function)', content)
        content = re.sub(r'const\s+test\s*=\s*async\s*\(name,\s*fn\)\s*=>', r'const test = async (name: string, fn: Function) =>', content)
        content = re.sub(r'const\s+setup\s*=\s*\(name\)\s*=>', r'const setup = (name: string) =>', content)
        content = re.sub(r'catch\s*\(\s*e\s*\)', r'catch (e: any)', content)
        content = re.sub(r'function\s+parseToken\(token\)', r'function parseToken(token: string)', content)
        content = re.sub(r'mockMiddleware\s*=\s*\(mock,\s*fn\)\s*=>', r'mockMiddleware = (mock: any, fn: Function) =>', content)
        content = re.sub(r'\(c\)\s*=>\s*c\.name', r'(c: any) => c.name', content)
        content = re.sub(r'\(c\)\s*=>\s*c\.status', r'(c: any) => c.status', content)
        
        # missing modules
        content = content.replace('./src/lib/supabaseAdmin', '../src/utils/supabase/admin')
        content = content.replace('../src/lib/supabaseAdmin', '../../src/utils/supabase/admin')

        with open(file, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Patched {file}")
    except Exception as e:
        print(f"Failed to patch {file}: {e}")

