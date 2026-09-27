const { Client } = require('pg');
async function run() {
    const client = new Client({ user: 'postgres', host: 'localhost', database: 'postgres', port: 54522, password: 'postgres' });
    await client.connect();
    
    let res = await client.query(`
        WITH Dups AS (
            SELECT COALESCE(raw_data->>'block code', raw_data->>'development block code') as code
            FROM staging.geography_imports 
            WHERE release_id = (SELECT id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R15') 
            AND entity_type = 'BLOCK' 
            GROUP BY COALESCE(raw_data->>'block code', raw_data->>'development block code') 
            HAVING count(*) > 1
        )
        SELECT 
            raw_data->>'state name' as state_name,
            raw_data->>'district name' as district_name,
            COALESCE(raw_data->>'block code', raw_data->>'development block code') as block_code,
            COALESCE(raw_data->>'block name', raw_data->>'development block name (in english)') as block_name,
            raw_data->>'block version' as version,
            internal_member_or_sheet,
            physical_row_number
        FROM staging.geography_imports
        WHERE release_id = (SELECT id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R15') 
        AND entity_type = 'BLOCK'
        AND COALESCE(raw_data->>'block code', raw_data->>'development block code') IN (SELECT code FROM Dups)
        ORDER BY block_code, physical_row_number
    `);
    
    console.table(res.rows);
    
    await client.end();
}
run();
