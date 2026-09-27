const { Client } = require('pg');
async function run() {
    const client = new Client({ user: 'postgres', host: 'localhost', database: 'postgres', port: 54522, password: 'postgres' });
    await client.connect();
    
    while (true) {
        let res = await client.query("SELECT count(*) as pending FROM data_imports.batches WHERE status != 'STAGED' AND release_id = (SELECT id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R15')");
        if (res.rows[0].pending == 0) break;
        await new Promise(r => setTimeout(r, 2000));
    }
    
    console.log('Finished!');
    
    let stats = await client.query("SELECT entity_type, count(*) as count FROM staging.geography_imports WHERE release_id = (SELECT id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R15') GROUP BY entity_type ORDER BY entity_type");
    console.log(stats.rows);
    await client.end();
}
run();
