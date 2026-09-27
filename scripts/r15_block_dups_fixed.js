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
    
    // State wise block counts
    let state_counts = await client.query(
        WITH StateBlocks AS (
            SELECT 
                (SELECT string_agg(DISTINCT raw_data->>'state code', '') FROM staging.geography_imports si WHERE si.batch_id = b.batch_id AND entity_type = 'DISTRICT') as state_code,
                (SELECT string_agg(DISTINCT raw_data->>'state name', '') FROM staging.geography_imports si WHERE si.batch_id = b.batch_id AND entity_type = 'DISTRICT') as state_name,
                count(*) as staged_count
            FROM staging.geography_imports b
            WHERE b.release_id = (SELECT id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R15') 
            AND b.entity_type = 'BLOCK'
            GROUP BY b.batch_id
        )
        SELECT * FROM StateBlocks ORDER BY state_code
    );
    console.log('State counts:', state_counts.rows.slice(0,5));
    
    await client.end();
}
run();
