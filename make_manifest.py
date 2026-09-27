import hashlib
import json
import glob
import os

files_to_hash = [
    'supabase/migrations/20260918000001_unit_master_schema.sql',
    'unit_master_rehearsal.sql',
    'scripts/import_units.ts',
    'parse.py',
    'seed/unece_raw.csv',
    'seed/unece_parsed.json',
    'tests/importer.test.ts'
]

with open('SHA256_MANIFEST.txt', 'w', encoding='utf-8') as mf:
    mf.write("UNIT MASTER REVIEW PACKAGE MANIFEST\n===================================\n")
    for filepath in files_to_hash:
        with open(filepath, 'rb') as f:
            h = hashlib.sha256(f.read()).hexdigest()
            mf.write(f"{h}  {os.path.basename(filepath)}\n")

print("Created SHA256_MANIFEST.txt")
