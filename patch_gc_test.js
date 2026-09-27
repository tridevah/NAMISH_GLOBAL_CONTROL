const fs = require('fs');
const p = 'D:/NAMISH_GLOBAL_CONTROL/src/app/api/s2s/provision-enterprise/__tests__/route.test.ts';
let code = fs.readFileSync(p, 'utf8');

code = code.replace(/jti: '123'/g, "jti: '123e4567-e89b-12d3-a456-426614174000'");
code = code.replace(/erp_app_user_id: 'uid'/g, "erp_app_user_id: '123e4567-e89b-12d3-a456-426614174001'");

fs.writeFileSync(p, code);
