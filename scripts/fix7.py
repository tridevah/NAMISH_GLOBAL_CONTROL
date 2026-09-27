with open('D:/NAMISH_GLOBAL_CONTROL/r16_cli_commit_20260901_203200/supabase/migrations/20260901000004_r16_promotion_commit.sql', 'r') as f:
    content = f.read()

# The runner manages its own transaction. We need to:
# 1. Remove the BEGIN ISOLATION LEVEL SERIALIZABLE; at top
# 2. Add SET TRANSACTION ISOLATION LEVEL SERIALIZABLE inside the DO block instead  
# 3. Remove the trailing COMMIT;
# 4. Add the isolation level as the first statement inside the DO BEGIN

content = content.replace(
    'BEGIN ISOLATION LEVEL SERIALIZABLE;\nSELECT pg_advisory_xact_lock(hashtext(\'LGD_CORE_PROMOTION\'));\nSET search_path TO catalog, staging, data_imports, public;\nSET CONSTRAINTS ALL IMMEDIATE;',
    'SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;\nSELECT pg_advisory_xact_lock(hashtext(\'LGD_CORE_PROMOTION\'));\nSET search_path TO catalog, staging, data_imports, public;\nSET CONSTRAINTS ALL IMMEDIATE;'
)

# Remove trailing COMMIT;
import re
content = re.sub(r'\nCOMMIT;\s*$', '', content)

with open('D:/NAMISH_GLOBAL_CONTROL/r16_cli_commit_20260901_203200/supabase/migrations/20260901000004_r16_promotion_commit.sql', 'w') as f:
    f.write(content)
print('Fixed - removed BEGIN/COMMIT, replaced with SET TRANSACTION.')
print(repr(content[:300]))
