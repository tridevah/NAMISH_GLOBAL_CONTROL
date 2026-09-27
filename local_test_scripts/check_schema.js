const { Client } = require('pg');
require('dotenv').config({ path: '.env.local' });

async function run() {
    const client = new Client({ connectionString: process.env.DATABASE_URL });
    await client.connect();
    
    // Check outbox tables
    const res = await client.query(`
        SELECT table_name, column_name, data_type 
        FROM information_schema.columns 
        WHERE table_schema = 'integration' AND table_name IN ('outbox_events', 'event_deliveries', 'webhook_deliveries', 'endpoints', 'webhook_endpoints', 'subscriptions');
    `);
    console.table(res.rows);
    
    // Check create_business_release
    const res2 = await client.query(`
        SELECT pg_get_functiondef(oid)
        FROM pg_proc
        WHERE proname = 'create_business_release';
    `);
    console.log(res2.rows[0].pg_get_functiondef);

    // Check publish_draft_release
    const res3 = await client.query(`
        SELECT pg_get_functiondef(oid)
        FROM pg_proc
        WHERE proname = 'publish_draft_release';
    `);
    console.log(res3.rows[0].pg_get_functiondef);

    await client.end();
}
run();
