with open('D:/NAMISH_GLOBAL_CONTROL/r16_cli_commit_20260901_203200/supabase/migrations/20260901000003_r16_promotion_commit.sql', 'r') as f:
    content = f.read()

# Fix the table name: geography_releases -> releases
content = content.replace('data_imports.geography_releases', 'data_imports.releases')

with open('D:/NAMISH_GLOBAL_CONTROL/r16_cli_commit_20260901_203200/supabase/migrations/20260901000003_r16_promotion_commit.sql', 'w') as f:
    f.write(content)
print('Fixed table name.')
