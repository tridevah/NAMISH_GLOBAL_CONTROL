const { Client } = require('pg');
async function run() {
    const client = new Client({ user: 'postgres', host: 'localhost', database: 'postgres', port: 54522, password: 'postgres' });
    await client.connect();
    
    // 1. Check Delhi Blocks
    let delhi = await client.query("SELECT * FROM staging.geography_imports WHERE release_id = (SELECT id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R15') AND entity_type = 'BLOCK' AND raw_data->>'State Code' = '7'");
    console.log('Delhi blocks:', delhi.rowCount);
    
    // 2. Check source provenance
    let prov = await client.query("SELECT e.path, o.logical_entity FROM data_imports.release_manifest_entries e JOIN data_imports.release_manifest_logical_outputs o ON e.id = o.manifest_entry_id WHERE e.release_id = (SELECT id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R15') AND o.logical_entity = 'BLOCK'");
    let arunachal_paths = prov.rows.filter(r => r.path.includes('ARUNACHAL'));
    let other_paths = prov.rows.filter(r => !r.path.includes('ARUNACHAL'));
    console.log('Arunachal Paths:', arunachal_paths.length);
    console.log('Other Paths includes All_Blockof_India?', other_paths.some(r => r.path.includes('All_Block')));
    
    // 3. Let's dump State-wise block counts
    let state_counts = await client.query("SELECT SUBSTRING(internal_member_or_sheet FROM 1 FOR 30) as file, count(*) FROM staging.geography_imports WHERE release_id = (SELECT id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R15') AND entity_type = 'BLOCK' GROUP BY internal_member_or_sheet ORDER BY count DESC LIMIT 10");
    console.log('Top block files:', state_counts.rows);
    
    // 4. Any header/footer rows?
    let headers = await client.query("SELECT * FROM staging.geography_imports WHERE release_id = (SELECT id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R15') AND entity_type = 'BLOCK' AND (raw_data->>'development block code' IS NULL OR raw_data->>'development block code' = '')");
    console.log('Null/Empty Block Codes:', headers.rowCount);
    
    // 5. Look for duplicates on block code
    let dups = await client.query("SELECT raw_data->>'development block code' as code, count(*) FROM staging.geography_imports WHERE release_id = (SELECT id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R15') AND entity_type = 'BLOCK' GROUP BY code HAVING count(*) > 1");
    console.log('Duplicate block codes:', dups.rowCount);
    if(dups.rowCount > 0) {
        console.log('Dups:', dups.rows.slice(0,5));
    }
    
    // 6. Distinct official block code
    let distinct = await client.query("SELECT count(DISTINCT raw_data->>'development block code') FROM staging.geography_imports WHERE release_id = (SELECT id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R15') AND entity_type = 'BLOCK'");
    console.log('Distinct block codes:', distinct.rows[0].count);
    
    // 7. Check for status or inactive columns
    let sample = await client.query("SELECT raw_data FROM staging.geography_imports WHERE release_id = (SELECT id FROM data_imports.releases WHERE release_name = 'LGD_20260826_CORE_R15') AND entity_type = 'BLOCK' LIMIT 1");
    console.log('Sample raw data:', sample.rows[0].raw_data);
    
    await client.end();
}
run();
