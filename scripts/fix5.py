with open('D:/NAMISH_GLOBAL_CONTROL/r16_cli_commit_20260901_203200/supabase/migrations/20260901000004_r16_promotion_commit.sql', 'r') as f:
    content = f.read()

content = content.replace(
    "IF v_batches != 143 THEN RAISE EXCEPTION 'Batches != 143 (actual remote), got: ' || v_batches; END IF;",
    "IF v_batches != 143 THEN RAISE EXCEPTION 'Batches != 143 (actual remote), got: %', v_batches; END IF;"
)
content = content.replace(
    "IF v_staged != 143 THEN RAISE EXCEPTION 'Staged batches != 143, got: ' || v_staged; END IF;",
    "IF v_staged != 143 THEN RAISE EXCEPTION 'Staged batches != 143, got: %', v_staged; END IF;"
)

with open('D:/NAMISH_GLOBAL_CONTROL/r16_cli_commit_20260901_203200/supabase/migrations/20260901000004_r16_promotion_commit.sql', 'w') as f:
    f.write(content)
print('Fixed.')
