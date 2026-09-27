const { Client } = require('pg');
async function run() {
    const client = new Client({ user: 'postgres', host: 'localhost', database: 'postgres', port: 54522, password: 'postgres' });
    await client.connect();
    
    let res = await client.query("SELECT (raw_data->>'development block code') as code, count(*) as count FROM staging.geography_imports WHERE release_id = (SELECT id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R15') AND entity_type = 'BLOCK' GROUP BY (raw_data->>'development block code') HAVING count(*) > 1");
    console.log('Duplicate Blocks:', res.rows);
    
    await client.end();
}
run();
