import json
with open('seed/unece_parsed.json', 'r', encoding='utf-8') as f:
    data = json.load(f)
for m in data['india_uqc_mappings']:
    print(f"{m['uqc_code']} -> {m['target_code']} | Status: {m['target_status']} (Source: {m['target_source_status']}) | {m['outcome']} ({m['basis']})")
