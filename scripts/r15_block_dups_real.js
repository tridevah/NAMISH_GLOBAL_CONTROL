const { Client } = require('pg');
async function run() {
    const client = new Client({ user: 'postgres', host: 'localhost', database: 'postgres', port: 54522, password: 'postgres' });
    await client.connect();
    
    // Check duplicates taking both keys into account
    let dups = await client.query("SELECT COALESCE(raw_data->>'block code', raw_data->>'development block code') as code, count(*) FROM staging.geography_imports WHERE release_id = (SELECT id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R15') AND entity_type = 'BLOCK' GROUP BY COALESCE(raw_data->>'block code', raw_data->>'development block code') HAVING count(*) > 1");
    console.log('Duplicate block codes:', dups.rowCount);
    if(dups.rowCount > 0) {
        console.log('Dups:', dups.rows.slice(0,5));
    }
    
    let distinct = await client.query("SELECT count(DISTINCT COALESCE(raw_data->>'block code', raw_data->>'development block code')) FROM staging.geography_imports WHERE release_id = (SELECT id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R15') AND entity_type = 'BLOCK'");
    console.log('Distinct block codes:', distinct.rows[0].count);
    
    // The exact 15 extra blocks!
    // Since expected is 7323 and actual is 7338... wait, where are the 15 extra?
    // We need to compare to expected blocks. We don't have expected blocks in DB easily, but we know there are 15 duplicates IF distinct is 7323 and rowCount is 7338.
    console.log('Total Block rows:', await client.query("SELECT count(*) FROM staging.geography_imports WHERE release_id = (SELECT id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R15') AND entity_type = 'BLOCK'").then(r => r.rows[0].count));
    
    // Check Delhi
    let delhi = await client.query("SELECT count(*) FROM staging.geography_imports WHERE release_id = (SELECT id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R15') AND entity_type = 'BLOCK' AND raw_data->>'state name' = 'DELHI'");
    console.log('Delhi blocks:', delhi.rows[0].count);
    
    await client.end();
}
run();
