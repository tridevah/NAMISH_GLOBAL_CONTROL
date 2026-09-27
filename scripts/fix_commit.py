with open('D:/NAMISH_GLOBAL_CONTROL/r16_cli_commit_20260901_203200/supabase/migrations/20260901000003_r16_promotion_commit.sql', 'r') as f:
    sql = f.read()

sql = sql.replace('END;\n;\nCOMMIT;', 'END;\n;\nCOMMIT;')
sql = sql.replace('END;\r\n;\r\nCOMMIT;', 'END;\n;\nCOMMIT;')
sql = sql.replace('END;\n$;\nCOMMIT;', 'END;\n;\nCOMMIT;')
sql = sql.replace('END;\r\n$;\r\nCOMMIT;', 'END;\n;\nCOMMIT;')

with open('D:/NAMISH_GLOBAL_CONTROL/r16_cli_commit_20260901_203200/supabase/migrations/20260901000003_r16_promotion_commit.sql', 'w') as f:
    f.write(sql)
print('Fixed')
