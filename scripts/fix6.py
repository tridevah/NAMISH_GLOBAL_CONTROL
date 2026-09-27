with open('D:/NAMISH_GLOBAL_CONTROL/r16_cli_commit_20260901_203200/supabase/migrations/20260901000004_r16_promotion_commit.sql', 'r') as f:
    content = f.read()

import re
# Fix all RAISE EXCEPTION with || concatenation
content = content.replace(
    "IF c_staging != 15250 THEN RAISE EXCEPTION 'Staging rows != 15250, got: ' || c_staging; END IF;",
    "IF c_staging != 15250 THEN RAISE EXCEPTION 'Staging rows != 15250, got: %', c_staging; END IF;"
)

with open('D:/NAMISH_GLOBAL_CONTROL/r16_cli_commit_20260901_203200/supabase/migrations/20260901000004_r16_promotion_commit.sql', 'w') as f:
    f.write(content)
print('Fixed.')
