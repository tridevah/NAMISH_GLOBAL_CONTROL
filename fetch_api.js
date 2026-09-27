import http from 'http';

http.get('http://localhost:3001/api/data-hub/units', (res) => {
  let data = '';
  res.on('data', (chunk) => { data += chunk; });
  res.on('end', () => { console.log(res.statusCode, data); });
}).on('error', (err) => {
  console.error('Error:', err.message);
});
