const https = require('https');
https.get('https://cbic-gst.gov.in/gst-acts.html', { rejectUnauthorized: false, headers: { 'User-Agent': 'Mozilla/5.0' } }, (res) => {
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    const links = data.match(/href=["'][^"']*?\.pdf["']/ig);
    console.log(links ? links.slice(0, 20) : 'No PDFs found');
  });
});
