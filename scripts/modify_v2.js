const fs = require('fs');
let code = fs.readFileSync('scripts/lgd_import_r12_physical_v2.js', 'utf8');

// Replace getBatchId definition
code = code.replace(
  /async function getBatchId\(client, releaseId, entityType\) \{[\s\S]*?return ins\.rows\[0\]\.id;\s*\}/,
  'async function getBatchId(client, releaseId, entityType, logicalBatchKey) {\n' +
  '    if (!logicalBatchKey) throw new Error("logicalBatchKey is strictly required in v2");\n' +
  '    const r = await client.query(\n' +
  '        \\'SELECT id FROM data_imports.batches WHERE release_id= AND logical_batch_key= AND entity_type=\\',\n' +
  '        [releaseId, logicalBatchKey, entityType]);\n' +
  '    if (r.rows.length === 1) return r.rows[0].id;\n' +
  '    throw new Error(getBatchId exact match failed for entity_type= logical_batch_key=. Matches: );\n' +
  '}'
);

// Replace loop
code = code.replace(
  /for \(const logicalEntity of entry\.logical_outputs\) \{/,
  'for (let idx = 0; idx < entry.logical_outputs.length; idx++) {\n            const logicalEntity = entry.logical_outputs[idx];'
);

// Replace logicalEntity getBatchId call
code = code.replace(
  /const batchId = await getBatchId\(client, releaseId, logicalEntity\);/,
  "const batchId = await getBatchId(client, releaseId, logicalEntity, entry.path + '!' + logicalEntity + '!' + idx);"
);

// Replace PINCODE/POST_OFFICE calls
code = code.replace(
  /const batchIdPincode\s*=\s*await getBatchId\(client, releaseId, 'PINCODE'\);/,
  "const batchIdPincode    = await getBatchId(client, releaseId, 'PINCODE', 'PIN CODE.csv!!PINCODE!0');"
);
code = code.replace(
  /const batchIdPostOffice = await getBatchId\(client, releaseId, 'POST_OFFICE'\);/,
  "const batchIdPostOffice = await getBatchId(client, releaseId, 'POST_OFFICE', 'PIN CODE.csv!!POST_OFFICE!0');"
);
code = code.replace(
  /const batchIdPV = await getBatchId\(client, releaseId, 'PIN_VILLAGE'\);/,
  "const batchIdPV = await getBatchId(client, releaseId, 'PIN_VILLAGE', 'Pincodeto_Village_Mapping.xlsx!!PIN_VILLAGE!0');"
);
code = code.replace(
  /const batchIdPU = await getBatchId\(client, releaseId, 'PIN_URBAN_LOCAL_BODY'\);/,
  "const batchIdPU = await getBatchId(client, releaseId, 'PIN_URBAN_LOCAL_BODY', 'Pincodeto_Urban_Mapping.xlsx!!PIN_URBAN_LOCAL_BODY!0');"
);

fs.writeFileSync('scripts/lgd_import_r12_physical_v2.js', code);
console.log('Modifications applied');
