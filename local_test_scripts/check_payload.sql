SELECT payload 
FROM integration.outbox_events 
WHERE event_type = 'catalog.release.published' 
LIMIT 1;
