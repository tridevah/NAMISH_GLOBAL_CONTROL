import hashlib
import json

def get_hash(filepath):
    with open(filepath, 'rb') as f:
        return hashlib.sha256(f.read()).hexdigest()

print("File Hashes:")
print(f"supabase/migrations/20260918000001_unit_master_schema.sql: {get_hash('supabase/migrations/20260918000001_unit_master_schema.sql')}")
print(f"rollback_unit_master.sql: {get_hash('rollback_unit_master.sql')}")
print(f"scripts/import_units.ts: {get_hash('scripts/import_units.ts')}")
print(f"parse.py: {get_hash('parse.py')}")
print(f"seed/unece_parsed.json: {get_hash('seed/unece_parsed.json')}")

with open('seed/unece_parsed.json', 'r', encoding='utf-8') as f:
    data = json.load(f)
    
print("\nReconciliation:")
print(f"Raw source hash (from provenance): {data['provenance']['sha256']}")
print(f"Total units mapped/prepared: {len(data['units'])}")
print(f"Total UQC records: {len(data['india_uqc_mappings'])}")
print(f"Total conversions: {len(data['unit_conversions'])}")
