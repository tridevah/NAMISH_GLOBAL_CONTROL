const https = require('https');
const fs = require('fs');
https.get('https://lgdirectory.gov.in/downloadDirectory.do', {
    rejectUnauthorized: false
}, (res) => {
    let data = '';
    res.on('data', (chunk) => { data += chunk; });
    res.on('end', () => {
        fs.writeFileSync('D:/NAMISH_GLOBAL_CONTROL/scripts/downloadDirectory2.html', data);
        console.log('Done downloading');
    });
}).on('error', (err) => {
    console.log('Error: ' + err.message);
});
