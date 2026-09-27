-- Get existing RPCs
SELECT proname, pg_get_functiondef(oid) as def
FROM pg_proc
WHERE proname IN ('create_business_release', 'publish_draft_release')
  AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'catalog');
