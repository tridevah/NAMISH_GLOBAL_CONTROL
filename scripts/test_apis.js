const http = require('http');
const INDIA_UUID = 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d';

function get(path) {
  return new Promise((resolve) => {
    const opts = {
      hostname: 'localhost',
      port: 3000,
      path,
      method: 'GET',
      headers: { 'Cookie': '' }
    };
    const req = http.get(opts, (res) => {
      let body = '';
      res.on('data', c => body += c);
      res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, body }));
    });
    req.on('error', e => resolve({ status: 'ERROR', body: e.message }));
  });
}

async function main() {
  const urls = [
    `/api/data-hub/tax/authorities?country=${INDIA_UUID}`,
    `/api/data-hub/tax/india-gst?country=${INDIA_UUID}`,
    `/api/data-hub/tax?country=${INDIA_UUID}`,
  ];
  for (const url of urls) {
    const r = await get(url);
    console.log('\n=== GET', url, '===');
    console.log('Status:', r.status);
    console.log('Body:', r.body.substring(0, 2000));
  }
}
main();
