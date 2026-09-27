npx supabase db query "SELECT e.url FROM integration.topic_subscriptions s JOIN integration.endpoints e ON s.endpoint_id = e.id WHERE s.id = 'b5f94e80-af81-4236-abf8-a361d2846c11';" --linked
