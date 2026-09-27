const pool = new require('pg').Pool({ connectionString: 'postgresql://postgres:postgres@localhost:54522/postgres' }); 
pool.query("SELECT id FROM data_imports.releases WHERE release_name='LGD_20260826_CORE_R10'").then(res => { console.log(typeof res.rows[0].id, res.rows[0].id); process.exit(0); });
