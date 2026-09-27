const https = require('https');
const url = 'https://cbic-gst.gov.in/gst-acts.html';
https.get(url, { rejectUnauthorized: false, headers: { 'User-Agent': 'Mozilla/5.0' } }, (res) => {
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    const lines = data.split('\n');
    const actLines = lines.filter(l => l.toLowerCase().includes('act') && l.includes('.pdf'));
    console.log(actLines.join('\n'));
  });
});
