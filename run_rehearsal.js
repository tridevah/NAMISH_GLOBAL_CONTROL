const { Client } = require('pg');
const fs = require('fs');

async function run() {
    const client = new Client({
        connectionString: 'postgresql://postgres:postgres@127.0.0.1:54522/postgres'
    });
    await client.connect();

    const sql = fs.readFileSync('rehearsal_000030.sql', 'utf8');
    
    // We can run BEGIN, DO $$, ROLLBACK as separate statements or in one query
    try {
        console.log("Starting Rehearsal...");
        client.on('notice', msg => console.log('NOTICE:', msg.message));
        
        await client.query("BEGIN ISOLATION LEVEL SERIALIZABLE;");
        
        // Find DO block
        const match = sql.match(/DO \$\$.*?END \$\$;/s);
        if (!match) throw new Error("Could not find DO block");
        
        await client.query(match[0]);
        
        await client.query("ROLLBACK;");
        console.log("Rollback completed.");

    } catch (e) {
        console.error("Error during execution:", e.message);
        await client.query("ROLLBACK;").catch(() => {});
    } finally {
        await client.end();
    }
}
run();
