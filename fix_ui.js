const fs = require('fs');
let content = fs.readFileSync('src/app/(protected)/data-hub/units/UnitsClient.tsx', 'utf-8');
content = content.replace(/\\`/g, '`');
content = content.replace(/\\\$/g, '$');
fs.writeFileSync('src/app/(protected)/data-hub/units/UnitsClient.tsx', content);
