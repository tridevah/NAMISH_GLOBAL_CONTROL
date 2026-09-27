const {Client} = require('pg');
const c = new Client({connectionString:'postgresql://postgres:postgres@localhost:54522/postgres'});
c.connect().then(async () => {
    // Get India country record
    const r1 = await c.query('SELECT * FROM catalog.countries LIMIT 3');
    console.log('COUNTRIES sample:', r1.rows);

    // Get geography levels
    const r2 = await c.query('SELECT * FROM catalog.geography_levels ORDER BY 1');
    console.log('GEO_LEVELS:', r2.rows);

    // Get local_body enum values
    const r3 = await c.query("SELECT enumlabel FROM pg_enum e JOIN pg_type t ON t.oid=e.enumtypid WHERE t.typname LIKE '%local_body%' ORDER BY enumsortorder");
    console.log('LOCAL_BODY_ENUM:', r3.rows.map(r=>r.enumlabel));

    // Count existing canonical rows
    const tables = ['geography_units','development_blocks','block_villages','local_bodies','local_body_villages','wards','ward_villages','postal_codes','post_offices','postal_code_geographies','postal_code_local_bodies'];
    for (const t of tables) {
        const rc = await c.query('SELECT COUNT(*) FROM catalog.' + t);
        console.log(t + ':', rc.rows[0].count);
    }

    await c.end();
}).catch(e => { console.error(e.message); process.exit(1); });
