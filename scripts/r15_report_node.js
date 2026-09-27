const { Client } = require('pg');
async function run() {
    const client = new Client({ user: 'postgres', host: 'localhost', database: 'postgres', port: 54522, password: 'postgres' });
    await client.connect();
    
    let res = await client.query("SELECT entity_type, count(*) as count FROM staging.geography_imports WHERE release_id = (SELECT id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R15') GROUP BY entity_type ORDER BY entity_type");
    console.log(res.rows);
    
    let dups = await client.query("SELECT entity_type, (raw_data->>'District Code') as district_code, count(*) FROM staging.geography_imports WHERE release_id = (SELECT id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R15') AND entity_type = 'DISTRICT' GROUP BY entity_type, (raw_data->>'District Code') HAVING count(*) > 1");
    console.log("Duplicate Districts:", dups.rows);
    await client.end();
}
run();
