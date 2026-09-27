SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_schema = 'integration' AND table_name IN ('delivery_state', 'topic_subscriptions');
