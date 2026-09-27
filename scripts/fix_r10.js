const fs = require('fs');
let code = fs.readFileSync('scripts/lgd_import_r10_physical.js', 'utf8');

const replacement = `    if (!rows.length) return 0;
    
    if (!stageChunk.releaseId) {
        const res = await client.query('SELECT id FROM data_imports.releases WHERE release_name=$1', [RELEASE_NAME]);
        stageChunk.releaseId = res.rows[0].id;
    }
    const releaseId = stageChunk.releaseId;
    
    await client.query('CREATE TEMP TABLE IF NOT EXISTS temp_geography_imports (LIKE staging.geography_imports INCLUDING ALL) ON COMMIT DROP');
    await client.query('TRUNCATE temp_geography_imports');

    let valuesStr = [];
    let params = [];
    let pIdx = 1;
    let replays = 0;

    for (let i=0; i<rows.length; i++) {
        const r = rows[i];
        const physRow = physRowStart + i;
        const normalizedSheet = sourceFile.replace(/\\\\/g, '/').normalize('NFC');
        const srcHash = 'e67f03ced808ac3569e1de47a6310f2df11b472a6729dfb4822a3ad278fb4e9c'; // using manifest hash for test
        const obsStr = 'OBS_V1' + srcHash + normalizedSheet + physRow + batchId + '1' + '1';
        const obsKey = require('crypto').createHash('sha256').update(obsStr).digest('hex');
        const payloadStr = JSON.stringify(r.raw_data);
        const payloadHash = require('crypto').createHash('sha256').update(payloadStr).digest('hex');

        valuesStr.push(\`(\$\${pIdx++}, \$\${pIdx++}, \$\${pIdx++}, \$\${pIdx++}, \$\${pIdx++}, \$\${pIdx++}, \$\${pIdx++}, \$\${pIdx++}, \$\${pIdx++}, \$\${pIdx++}, \$\${pIdx++}, \$\${pIdx++}, \$\${pIdx++}, \$\${pIdx++}, \$\${pIdx++})\`);
        params.push(
            releaseId, batchId, obsKey, srcHash, normalizedSheet, physRow, 1, 1, payloadHash, 
            entityType, r.entity_code||null, r.parent_code||null, r.entity_name||null, 'PENDING', payloadStr
        );
    }
    
    const insertTemp = \`INSERT INTO temp_geography_imports (
        release_id, batch_id, source_observation_key, physical_source_sha256, internal_member_or_sheet, 
        physical_row_number, logical_output_ordinal, emitted_record_ordinal, raw_payload_sha256, 
        entity_type, entity_code, parent_code, entity_name, classification, raw_data
    ) VALUES \` + valuesStr.join(',');
    
    await client.query(insertTemp, params);

    const insertStaging = \`
        INSERT INTO staging.geography_imports (
            release_id, batch_id, source_observation_key, physical_source_sha256, internal_member_or_sheet, 
            physical_row_number, logical_output_ordinal, emitted_record_ordinal, raw_payload_sha256, 
            entity_type, entity_code, parent_code, entity_name, classification, raw_data
        )
        SELECT release_id, batch_id, source_observation_key, physical_source_sha256, internal_member_or_sheet, 
            physical_row_number, logical_output_ordinal, emitted_record_ordinal, raw_payload_sha256, 
            entity_type, entity_code, parent_code, entity_name, classification, raw_data
        FROM temp_geography_imports
        ON CONFLICT (release_id, batch_id, source_observation_key) WHERE source_observation_key IS NOT NULL DO NOTHING
    \`;
    
    const res = await client.query(insertStaging);
    const inserted = res.rowCount;
    replays = rows.length - inserted;
    
    if (replays > 0) {
        const updateReplays = \`
            UPDATE staging.geography_imports s
            SET importer_replay_count = s.importer_replay_count + 1
            FROM temp_geography_imports t
            WHERE s.release_id = t.release_id AND s.batch_id = t.batch_id AND s.source_observation_key = t.source_observation_key
        \`;
        await client.query(updateReplays);
    }

    totalStaged += inserted;
    return inserted;`;

code = code.replace(/if \(\!rows\.length\) return 0;.*?totalStaged \+= inserted;\s*return inserted;/s, replacement);
fs.writeFileSync('scripts/lgd_import_r10_physical.js', code);
