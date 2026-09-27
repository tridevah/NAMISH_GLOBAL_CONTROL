const { Client } = require('pg');
async function run() {
    const client = new Client({ user: 'postgres', host: 'localhost', database: 'postgres', port: 54522, password: 'postgres' });
    await client.connect();
    
    // Check RLS on catalog.development_blocks
    let rls = await client.query("SELECT * FROM pg_policies WHERE schemaname = 'catalog' AND tablename = 'development_blocks'");
    console.log("Policies on development_blocks:", rls.rows);
    
    // Check RLS on catalog.geography_units
    let rls2 = await client.query("SELECT * FROM pg_policies WHERE schemaname = 'catalog' AND tablename = 'geography_units'");
    console.log("Policies on geography_units:", rls2.rows);

    await client.end();
}
run();
