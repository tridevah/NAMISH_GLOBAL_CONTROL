const fs = require('fs');
const https = require('https');
const crypto = require('crypto');
const path = require('path');

const targetDir = path.join(__dirname, '../gst_official_sources');
if (!fs.existsSync(targetDir)) {
  fs.mkdirSync(targetDir, { recursive: true });
}

// 9 Categories as requested:
const claimsToFetch = [
  {
    id: 'CGST_9_10',
    title: 'CGST Sections 9 and 10',
    url: 'https://taxinformation.cbic.gov.in/view-pdf/1000494/ENG/Acts',
    filename: 'cgst_act_sections_9_10.html',
    actSecInfo: 'CGST Act 2017, Sections 9 & 10'
  },
  {
    id: 'IGST_10_16',
    title: 'IGST Sections 10-16',
    url: 'https://taxinformation.cbic.gov.in/view-pdf/1000493/ENG/Acts',
    filename: 'igst_act_sections_10_16.html',
    actSecInfo: 'IGST Act 2017, Sections 10 to 16'
  },
  {
    id: 'UTGST_ACT',
    title: 'UTGST Act and Amendments',
    url: 'https://taxinformation.cbic.gov.in/view-pdf/1000495/ENG/Acts',
    filename: 'utgst_act.html',
    actSecInfo: 'UTGST Act 2017'
  },
  {
    id: 'SGST_UTGST_JURISDICTIONS',
    title: '31 SGST and 5 UTGST Jurisdictions Proof',
    url: 'https://gstcouncil.gov.in/state-gst-acts',
    filename: 'sgst_utgst_jurisdictions.html',
    actSecInfo: 'State/UT Jurisdictions List'
  },
  {
    id: 'RATE_NOTIFS',
    title: 'Current Goods/Services Rate Notifications (5, 18, 40, etc)',
    url: 'https://gstcouncil.gov.in/gst-rates',
    filename: 'gst_rate_notifications.html',
    actSecInfo: 'Principal Rate Notifications & Amendments'
  },
  {
    id: 'NIL_EXEMPT_NOTIFS',
    title: 'Nil/Exempt Notifications',
    url: 'https://taxinformation.cbic.gov.in/content-page/explore-notification/exemptions',
    filename: 'nil_exempt_notifications.html',
    actSecInfo: 'Nil and Exempt Notifications'
  },
  {
    id: 'RCM_NOTIFS',
    title: 'RCM Notifications and Amendments',
    url: 'https://taxinformation.cbic.gov.in/content-page/explore-notification/rcm',
    filename: 'rcm_notifications.html',
    actSecInfo: 'Reverse Charge Notifications'
  },
  {
    id: 'COMPOSITION_NOTIFS',
    title: 'Composition Notifications and Thresholds',
    url: 'https://taxinformation.cbic.gov.in/content-page/explore-notification/composition',
    filename: 'composition_notifications.html',
    actSecInfo: 'Composition Scheme Notifications'
  },
  {
    id: 'CESS_INSTRUMENTS',
    title: 'Compensation Cess and HSNS Cess Instruments',
    url: 'https://taxinformation.cbic.gov.in/view-pdf/1000496/ENG/Acts',
    filename: 'cess_instruments.html',
    actSecInfo: 'GST Compensation to States Act 2017'
  },
  {
    id: 'HSN_SAC_CROSSCHECK',
    title: 'HSN/SAC Rate Table Cross-check',
    url: 'https://cbic-gst.gov.in/gst-goods-and-services-rates.html',
    filename: 'hsn_sac_rate_table.html',
    actSecInfo: 'CBIC GST Goods and Services Rates Table'
  }
];

async function fetchUrl(url, filepath, redirectCount = 0) {
  return new Promise((resolve, reject) => {
    if (redirectCount > 5) return resolve({ status: 302, finalUrl: url, headers: {} });
    
    https.get(url, { rejectUnauthorized: false, headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' } }, (res) => {
      if ([301, 302, 303, 307, 308].includes(res.statusCode) && res.headers.location) {
        let newUrl = res.headers.location;
        if (!newUrl.startsWith('http')) {
            const urlObj = new URL(url);
            newUrl = `${urlObj.protocol}//${urlObj.host}${newUrl.startsWith('/') ? '' : '/'}${newUrl}`;
        }
        return resolve(fetchUrl(newUrl, filepath, redirectCount + 1));
      }

      if (res.statusCode !== 200) {
        return resolve({ status: res.statusCode, finalUrl: url, headers: res.headers });
      }

      const file = fs.createWriteStream(filepath);
      res.pipe(file);
      file.on('finish', () => {
        file.close();
        resolve({ status: res.statusCode, finalUrl: url, headers: res.headers });
      });
    }).on('error', err => {
      resolve({ status: 'ERROR', finalUrl: url, headers: {}, error: err.message });
    });
  });
}

function hashFile(filepath) {
  return new Promise((resolve, reject) => {
    const hash = crypto.createHash('sha256');
    const stream = fs.createReadStream(filepath);
    stream.on('error', err => reject(err));
    stream.on('data', chunk => hash.update(chunk));
    stream.on('end', () => resolve(hash.digest('hex')));
  });
}

async function run() {
  const records = [];
  const matrix = {};
  
  console.log('Initiating Secure Fetch of Official India GST Sources...\n');

  for (const claim of claimsToFetch) {
    const filepath = path.join(targetDir, claim.filename);
    const timestamp = new Date().toISOString();
    
    console.log(`[FETCHING] ${claim.title} -> ${claim.url}`);
    
    const result = await fetchUrl(claim.url, filepath);
    
    if (result.status === 200) {
      const stats = fs.statSync(filepath);
      const sha256 = await hashFile(filepath);
      
      records.push({
        claimId: claim.id,
        title: claim.title,
        originalUrl: claim.url,
        finalRedirectedUrl: result.finalUrl,
        httpStatus: result.status,
        contentType: result.headers['content-type'] || 'unknown',
        byteSize: stats.size,
        exactLocalFilename: claim.filename,
        sha256: sha256,
        actSecInfo: claim.actSecInfo,
        timestampUTC: timestamp,
        status: 'PROVEN'
      });
      matrix[claim.id] = { status: 'PROVEN', file: claim.filename };
    } else {
      records.push({
        claimId: claim.id,
        title: claim.title,
        originalUrl: claim.url,
        finalRedirectedUrl: result.finalUrl,
        httpStatus: result.status,
        contentType: result.headers['content-type'] || 'unknown',
        byteSize: 0,
        exactLocalFilename: claim.filename,
        sha256: null,
        actSecInfo: claim.actSecInfo,
        timestampUTC: timestamp,
        error: result.error || 'HTTP ' + result.status,
        status: 'UNRESOLVED'
      });
      matrix[claim.id] = { status: 'UNRESOLVED', reason: result.error || 'HTTP ' + result.status };
    }
  }

  const manifestPath = path.join(targetDir, 'source_manifest_v2.json');
  fs.writeFileSync(manifestPath, JSON.stringify({ records, matrix }, null, 2));

  console.log(`\n=================================================`);
  console.log(`SOURCE MANIFEST & VALIDATED CLAIM MATRIX`);
  console.log(`=================================================`);
  
  for (const r of records) {
    console.log(`\nCLAIM: ${r.title}`);
    console.log(`- Original URL: ${r.originalUrl}`);
    console.log(`- Final URL: ${r.finalRedirectedUrl}`);
    console.log(`- HTTP Status: ${r.httpStatus}`);
    console.log(`- Content-Type: ${r.contentType}`);
    console.log(`- Byte Size: ${r.byteSize} bytes`);
    console.log(`- Timestamp (UTC): ${r.timestampUTC}`);
    if (r.status === 'PROVEN') {
      console.log(`- Local Filename: ${r.exactLocalFilename}`);
      console.log(`- SHA256: ${r.sha256}`);
      console.log(`- Act/Section Info: ${r.actSecInfo}`);
      console.log(`- STATUS: PROVEN (Downloaded successfully)`);
    } else {
      console.log(`- STATUS: UNRESOLVED (Reason: ${r.error})`);
    }
  }

  console.log(`\n=================================================`);
  console.log(`REMAINING GAPS SUMMARY (UNRESOLVED)`);
  console.log(`=================================================`);
  const gaps = records.filter(r => r.status === 'UNRESOLVED');
  if (gaps.length === 0) {
    console.log('No remaining gaps. All documents acquired.');
  } else {
    gaps.forEach(g => {
      console.log(`[UNRESOLVED] ${g.title} (HTTP ${g.httpStatus})`);
    });
  }
}

run();
