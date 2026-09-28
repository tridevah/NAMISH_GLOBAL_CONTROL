SELECT proname, proacl
FROM pg_proc
WHERE proname IN ('create_business_release', 'publish_draft_release', 'create_business_release_wrapper', 'publish_draft_release_wrapper', 'get_release_review');
