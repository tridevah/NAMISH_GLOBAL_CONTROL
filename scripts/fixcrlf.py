import re

with open('D:/NAMISH_GLOBAL_CONTROL/r16_cli_commit_20260901_203200/supabase/migrations/20260901000003_r16_promotion_commit.sql', 'r') as f:
    content = f.read()

# Find the DO block and rebuild it cleanly
# The problem: DECLARE at 15318 is a sub-block declaration INSIDE BEGIN, which isn't valid in this position
# in the outer BEGIN scope. Sub-blocks in PL/pgSQL need BEGIN...END wrapping. 
# The assertions block is already wrapped in BEGIN...END (at 15322 and 15333)
# So the outer pre-DML assertions sub-block IS valid. 
# The issue is likely CRLF in dollar-quoting. Let's convert all CRLF to LF in the DO block.

# Find the DO  block
do_start = content.find('DO \$\$')
do_end = content.rfind('\$\$;') + 4

do_block = content[do_start:do_end]
# Normalize CRLF to LF inside the DO block
do_block_clean = do_block.replace('\r\n', '\n')

content = content[:do_start] + do_block_clean + content[do_end:]

with open('D:/NAMISH_GLOBAL_CONTROL/r16_cli_commit_20260901_203200/supabase/migrations/20260901000003_r16_promotion_commit.sql', 'w', newline='') as f:
    f.write(content)
print('CRLF normalized in DO block')
