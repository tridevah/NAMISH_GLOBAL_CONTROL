const { Client } = require('pg');
const crypto = require('crypto');
const fs = require('fs');

async function run() {
    const client = new Client({ user: 'postgres', host: 'localhost', database: 'postgres', port: 54522, password: 'postgres' });
    await client.connect();

    try {
        // 1. Hash Check
        const adapterContent = fs.readFileSync('D:\\NAMISH_GLOBAL_CONTROL\\scripts\\r16_phase_b_adapter.sql');
        const hash = crypto.createHash('sha256').update(adapterContent).digest('hex').toUpperCase();
        if (hash !== '331BC86318112715DE498448A85EBC6AB1C16A3E645ED19B8020607B6B0B4159') {
            throw new Error('Hash mismatch: ' + hash);
        }
        console.log('PRE-FLIGHT: Hash match ok.');

        // 2. Staging rows
        let res = await client.query("SELECT count(*) FROM staging.geography_imports WHERE release_id = '5fac63d7-0101-43c5-8867-bd75ff609861'");
        if (res.rows[0].count !== '15250') throw new Error('Staging rows mismatch: ' + res.rows[0].count);
        console.log('PRE-FLIGHT: 15250 staging rows ok.');

        // 3. Batches
        let batches = await client.query("SELECT status, count(*) FROM data_imports.batches WHERE release_id = '5fac63d7-0101-43c5-8867-bd75ff609861' GROUP BY status");
        let bmap = {};
        for (let r of batches.rows) bmap[r.status] = parseInt(r.count);
        if (bmap['STAGED'] !== 143 || bmap['OFFICIAL_EMPTY'] !== 1 || bmap['PENDING'] || bmap['FAILED'] || bmap['EXTRACTING']) {
            throw new Error('Batches mismatch: ' + JSON.stringify(bmap));
        }
        console.log('PRE-FLIGHT: Batches ok.');

        // 4. Locks
        let locks = await client.query("SELECT count(*) FROM pg_locks WHERE locktype = 'advisory'");
        console.log('PRE-FLIGHT: Locks active:', locks.rows[0].count);

        // 5. Bidirectional equality
        let equality = await client.query("SELECT gl.level_key, count(*) as c1 FROM catalog.geography_units gu JOIN catalog.geography_levels gl ON gu.geography_level_id = gl.id WHERE gl.level_key IN ('STATE_UT', 'DISTRICT', 'SUB_DISTRICT') GROUP BY gl.level_key");
        console.log('Canonical counts: ', equality.rows);
        
    } finally {
        await client.end();
    }
}
run().catch(e => { console.error(e); process.exit(1); });
