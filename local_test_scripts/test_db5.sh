ssh -i ~/.ssh/namish_erp_vps tridevah@97.74.92.189 << 'EOF'
sudo bash -c 'sed -i "/GC_DATABASE_URL/d" /etc/namish-global-control/production.env'
sudo bash -c 'echo "GC_DATABASE_URL=postgres://gc_dispatcher_worker.urxgjgwrwpeplxoeobhz:sEcUrE_dIsPaTcHeR_P@ss_9912@aws-0-ap-south-1.pooler.supabase.com:5432/postgres" >> /etc/namish-global-control/production.env'
sudo -u tridevah bash -c "cd /srv/namish-global-control/dispatcher && export \$(grep -v '^#' /etc/namish-global-control/production.env | xargs) && node -e \"
const { Client } = require('pg');
const client = new Client({ connectionString: process.env.GC_DATABASE_URL, ssl: { rejectUnauthorized: false } });
client.connect().then(() => {
    return client.query('BEGIN READ ONLY; SELECT current_user, current_database(); ROLLBACK;');
}).then(res => {
    console.log('PASS', res[1].rows[0]);
    process.exit(0);
}).catch(err => {
    console.error('FAIL', err);
    process.exit(1);
});
\""
EOF
