SELECT pg_get_triggerdef(oid) 
FROM pg_trigger 
WHERE tgname = 'trg_publish_release';

SELECT proname, pg_get_functiondef(oid)
FROM pg_proc
WHERE proname = 'fn_publish_release_event';
