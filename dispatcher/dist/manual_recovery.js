"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.executeManualRecovery = executeManualRecovery;
const db_1 = require("./db");
const sender_1 = require("./sender");
async function executeManualRecovery(authorizedBy) {
    try {
        const { rows } = await db_1.pool.query('SELECT * FROM integration.claim_recovery_caed6a85($1::text)', [authorizedBy]);
        if (rows.length === 0) {
            throw new Error('Recovery rejected: Zero rows returned.');
        }
        const job = rows[0];
        console.log(`[Attempt ${job.attempt_count}] Claimed recovery for ${job.event_id}`);
        const result = await (0, sender_1.processJob)(job);
        console.log('Result:', result);
        if (result.outcome !== 'SUCCESS') {
            console.error(`Manual recovery failed with outcome ${result.outcome}, HTTP ${result.httpStatus}`);
            process.exitCode = 1;
        }
    }
    finally {
        await db_1.pool.end();
    }
}
if (require.main === module) {
    const [, , authorizedBy] = process.argv;
    if (!authorizedBy) {
        console.error('Usage: node dist/manual_recovery.js <OperatorIdentity>');
        process.exit(1);
    }
    executeManualRecovery(authorizedBy).catch(err => {
        console.error('Manual recovery execution error:', err.message);
        process.exit(1);
    });
}
