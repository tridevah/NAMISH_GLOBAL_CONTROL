SELECT proname, pg_get_functiondef(oid)
FROM pg_proc
WHERE proname = 'fn_publish_release';
