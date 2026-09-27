const { Client } = require('pg');
async function run() {
    const client = new Client({ user: 'postgres', host: 'localhost', database: 'postgres', port: 54522, password: 'postgres' });
    await client.connect();
    
    // Get state names for these files
    let st = await client.query(
        SELECT DISTINCT raw_data->>'district name' as dname, raw_data->>'state name' as sname
        FROM staging.geography_imports
        WHERE release_id = (SELECT id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R15') 
        AND entity_type = 'DISTRICT'
    );
    
    let dmap = {};
    st.rows.forEach(r => { dmap[r.dname] = r.sname; });
    
    let res = await client.query(
        WITH Dups AS (
            SELECT COALESCE(raw_data->>'block code', raw_data->>'development block code') as code
            FROM staging.geography_imports 
            WHERE release_id = (SELECT id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R15') 
            AND entity_type = 'BLOCK' 
            GROUP BY COALESCE(raw_data->>'block code', raw_data->>'development block code') 
            HAVING count(*) > 1
        )
        SELECT 
            raw_data->>'district name' as district_name,
            COALESCE(raw_data->>'block code', raw_data->>'development block code') as block_code,
            COALESCE(raw_data->>'block name (in english)', raw_data->>'block name') as block_name,
            COALESCE(raw_data->>'block version', raw_data->>' development block version') as version,
            internal_member_or_sheet,
            physical_row_number,
            raw_data
        FROM staging.geography_imports
        WHERE release_id = (SELECT id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R15') 
        AND entity_type = 'BLOCK'
        AND COALESCE(raw_data->>'block code', raw_data->>'development block code') IN (SELECT code FROM Dups)
        ORDER BY block_code, physical_row_number
    );
    
    res.rows.forEach(r => {
        r.state_name = dmap[r.district_name];
    });
    
    console.log(JSON.stringify(res.rows, null, 2));
    
    // Header/footer
    let hf = await client.query(
        SELECT count(*) as c FROM staging.geography_imports
        WHERE release_id = (SELECT id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R15') 
        AND entity_type = 'BLOCK'
        AND COALESCE(raw_data->>'block code', raw_data->>'development block code') IS NULL
    );
    console.log("Header/Footer rows:", hf.rows[0].c);
    
    // Inactive status
    let st_ver = await client.query(
        SELECT count(*) as c FROM staging.geography_imports
        WHERE release_id = (SELECT id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R15') 
        AND entity_type = 'BLOCK'
        AND (raw_data->>'status' ILIKE '%inactive%' OR raw_data->>'status' ILIKE '%deleted%')
    );
    console.log("Inactive/deleted rows:", st_ver.rows[0].c);
    
    await client.end();
}
run();
