"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.poll = poll;
const db_1 = require("./db");
const sender_1 = require("./sender");
let isShuttingDown = false;
process.on('SIGINT', () => { isShuttingDown = true; });
process.on('SIGTERM', () => { isShuttingDown = true; });
async function poll() {
    if (!process.env.GC_DATABASE_URL)
        throw new Error('GC_DATABASE_URL not set');
    const { rows: [{ ok }] } = await db_1.pool.query("SELECT pg_has_role(current_user, 'gc_dispatcher_worker', 'USAGE') as ok");
    if (!ok && process.env.ALLOW_DB_ADMIN_OFFLINE_TEST !== 'true') {
        const { rows: [{ cur }] } = await db_1.pool.query("SELECT current_user as cur");
        throw new Error(`Worker must have gc_dispatcher_worker role privileges (was ${cur})`);
    }
    let runningOps = [];
    while (!isShuttingDown) {
        try {
            const { rows } = await db_1.pool.query('SELECT * FROM integration.claim_delivery($1::integer)', [10]);
            if (rows.length === 0) {
                await new Promise(r => setTimeout(r, 2000));
                continue;
            }
            for (const job of rows) {
                runningOps.push((0, sender_1.processJob)(job));
            }
            const results = await Promise.allSettled(runningOps);
            for (const r of results) {
                if (r.status === 'rejected') {
                    console.error('Job rejection:', r.reason);
                    throw r.reason;
                }
            }
            runningOps = [];
        }
        catch (err) {
            console.error('Polling error:', err);
            throw err;
        }
    }
    await db_1.pool.end();
}
if (require.main === module) {
    console.log('Dispatcher started');
    poll().catch((err) => {
        console.error('Fatal worker error:', err);
        process.exit(1);
    });
}
