import os
import zipfile
import hashlib
import sys
import shutil

files_to_hash = [
    'supabase/migrations/20260918000001_unit_master_schema.sql',
    'unit_master_rehearsal.sql',
    'scripts/import_units.ts',
    'parse.py',
    'seed/unece_raw.csv',
    'seed/unece_parsed.json',
    'tests/importer.test.ts'
]

# 1. Create Manifest
with open('SHA256_MANIFEST.txt', 'w', encoding='utf-8') as mf:
    mf.write("UNIT MASTER REVIEW PACKAGE MANIFEST\n===================================\n")
    for filepath in files_to_hash:
        with open(filepath, 'rb') as f:
            h = hashlib.sha256(f.read()).hexdigest()
            # Include relative path in manifest as requested
            mf.write(f"{h}  {filepath}\n")

# 2. Build ZIP
zip_name = 'Unit_Master_Review_Package.zip'
with zipfile.ZipFile(zip_name, 'w', zipfile.ZIP_DEFLATED) as zf:
    for f in files_to_hash + ['SHA256_MANIFEST.txt']:
        zf.write(f, f)

print(f"Created {zip_name}")

# 3. Extract and Verify
extract_dir = 'zip_check'
if os.path.exists(extract_dir):
    shutil.rmtree(extract_dir)
os.makedirs(extract_dir)

with zipfile.ZipFile(zip_name, 'r') as zf:
    zf.extractall(extract_dir)

print("\nVerifying extracted files...")

# Verify Manifest Matches
manifest_path = os.path.join(extract_dir, 'SHA256_MANIFEST.txt')
with open(manifest_path, 'r', encoding='utf-8') as f:
    lines = f.read().splitlines()[2:] # Skip header

for line in lines:
    expected_hash, rel_path = line.split('  ')
    extracted_path = os.path.join(extract_dir, rel_path)
    with open(extracted_path, 'rb') as ef:
        actual_hash = hashlib.sha256(ef.read()).hexdigest()
    if expected_hash != actual_hash:
        print(f"ERROR: Hash mismatch for {rel_path}!")
        sys.exit(1)
    else:
        print(f"Verified hash: {rel_path}")

# Verify Syntax (check for $$ in SQL files)
for sql_file in ['supabase/migrations/20260918000001_unit_master_schema.sql', 'unit_master_rehearsal.sql']:
    extracted_sql_path = os.path.join(extract_dir, sql_file)
    with open(extracted_sql_path, 'r', encoding='utf-8') as sf:
        content = sf.read()
        if '$$' not in content:
            print(f"ERROR: No dollar quotes ($$) found in {sql_file}")
            sys.exit(1)
        if 'BEGIN;' not in content and sql_file == 'unit_master_rehearsal.sql':
            print(f"ERROR: Missing BEGIN; in {sql_file}")
            sys.exit(1)
        if 'ROLLBACK;' not in content and sql_file == 'unit_master_rehearsal.sql':
            print(f"ERROR: Missing ROLLBACK; in {sql_file}")
            sys.exit(1)

print("\nSuccess: Syntax basic checks passed (dollar quotes present).")
print("Payload equivalence verified via hash comparison.")
