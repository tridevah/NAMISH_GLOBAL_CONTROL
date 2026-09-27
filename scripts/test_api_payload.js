const http = require('http');
const https = require('https');

async function check() {
    const url = 'http://127.0.0.1:54521/rest/v1/rpc/rpc_get_units';
    const key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU';
    const payload = JSON.stringify({
        p_country_id: 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d',
        p_limit: 200,
        p_offset: 0
    });

    const options = {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ' + key,
            'apikey': key,
            'Content-Length': Buffer.byteLength(payload)
        }
    };

    const req = http.request(url, options, (res) => {
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => {
            const parsed = JSON.parse(data);
            console.log('PAYLOAD SIZE:', Buffer.byteLength(data), 'bytes');
            console.log('ROWS:', parsed.rows ? parsed.rows.length : 'undefined');
            console.log('TOTAL:', parsed.total);
            console.log('STATUS:', res.statusCode);
        });
    });

    req.write(payload);
    req.end();
}
check();
