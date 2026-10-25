import { pool } from './db';
import { processJob } from './sender';

let isShuttingDown = false;
process.on('SIGINT', () => { isShuttingDown = true; });
process.on('SIGTERM', () => { isShuttingDown = true; });

export async function poll() {
    if (!process.env.GC_DATABASE_URL) throw new Error('GC_DATABASE_URL not set');
    const { rows: [{ ok }] } = await pool.query("SELECT pg_has_role(current_user, 'gc_dispatcher_worker', 'USAGE') as ok");
    if (!ok && process.env.ALLOW_DB_ADMIN_OFFLINE_TEST !== 'true') {
        const { rows: [{ cur }] } = await pool.query("SELECT current_user as cur");
        throw new Error(`Worker must have gc_dispatcher_worker role privileges (was ${cur})`);
    }

    let runningOps: Promise<{ outcome: string; httpStatus: number; responseBody: string }>[] = [];
    
    while (!isShuttingDown) {
        try {
            const { rows } = await pool.query('SELECT * FROM integration.claim_delivery($1::integer)', [10]);
            
            if (rows.length === 0) {
                await new Promise(r => setTimeout(r, 2000));
                continue;
            }

            for (const job of rows) {
                runningOps.push(processJob(job));
            }
            
            const results = await Promise.allSettled(runningOps);
            for (const r of results) {
                if (r.status === 'rejected') {
                    console.error('Job rejection:', r.reason);
                    throw r.reason; 
                }
            }
            runningOps = [];
        } catch (err) {
            console.error('Polling error:', err);
            throw err; 
        }
    }
    await pool.end();
}

if (require.main === module) {
    console.log('Dispatcher started');
    poll().catch((err) => {
        console.error('Fatal worker error:', err);
        process.exit(1);
    });
}
