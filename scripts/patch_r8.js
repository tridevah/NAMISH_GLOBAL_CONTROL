const fs = require('fs');
let content = fs.readFileSync('scripts/lgd_import_r8_physical.js', 'utf8');

// Replace inline promotion logic for standard entities
content = content.replace(/\/\/ Promote inline[\s\S]*?await completeBatch/g, 
  "let stats = {staged, inserted:0, updated:0, unchanged:0, rejected:0};\n                await completeBatch");

// Replace PINCODE promotion inline logic
content = content.replace(/const pcStats = await promotePostalCodes\(client, batchIdPincode\);/g, 
  "const pcStats = {staged: pinStaged, inserted:0, updated:0, unchanged:0, rejected:0};");

// Replace POST_OFFICE promotion inline logic
content = content.replace(/const poStats = await promotePostOffices[\s\S]*?;/g, 
  "const poStats = {staged: poStaged, inserted:0, updated:0, unchanged:0, rejected:0};");

// Replace PV promotion
content = content.replace(/const stats = await promotePostalCodeGeographies\(client, batchIdPV\);/g, 
  "const stats = {staged: pvStaged, inserted:0, updated:0, unchanged:0, rejected:0};");

// Replace PU promotion
content = content.replace(/const stats = await promotePostalCodeLocalBodies\(client, batchIdPU\);/g, 
  "const stats = {staged: puStaged, inserted:0, updated:0, unchanged:0, rejected:0};");

fs.writeFileSync('scripts/lgd_import_r8_physical.js', content);
