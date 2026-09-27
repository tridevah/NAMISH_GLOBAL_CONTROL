const { Client } = require('pg');
async function run() {
    const client = new Client({ user: 'postgres', host: 'localhost', database: 'postgres', port: 54522, password: 'postgres' });
    await client.connect();

    let res = await client.query(
        SELECT DISTINCT jsonb_object_keys(raw_data) as key
        FROM staging.geography_imports
        WHERE release_id = (SELECT id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R15') 
        AND entity_type = 'BLOCK'
    );
    
    console.log("Raw JSON keys for BLOCKS:", res.rows.map(r => r.key));

    // Check block 1000
    let b1000 = await client.query(
        SELECT raw_data
        FROM staging.geography_imports
        WHERE release_id = (SELECT id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R15') 
        AND entity_type = 'BLOCK'
        AND COALESCE(raw_data->>'block code', raw_data->>'development block code') = '1000'
    );
    console.log("Block 1000:", b1000.rows[0].raw_data);
    
    // Check AP blocks (Block Code 5374)
    let bAP = await client.query(
        SELECT raw_data
        FROM staging.geography_imports
        WHERE release_id = (SELECT id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R15') 
        AND entity_type = 'BLOCK'
        AND COALESCE(raw_data->>'block code', raw_data->>'development block code') = '5374'
    );
    console.log("Block 5374:", bAP.rows[0].raw_data);

    await client.end();
}
run();
