-- Actual delivery_state and delivery_attempts columns
SELECT table_name, column_name, data_type 
FROM information_schema.columns 
WHERE table_schema = 'integration' AND table_name IN ('delivery_state', 'delivery_attempts', 'topic_subscriptions', 'idempotency_records')
ORDER BY table_name, ordinal_position;
