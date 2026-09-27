const fs = require('fs');
const https = require('https');
const crypto = require('crypto');
const path = require('path');
const pdfParse = require('pdf-parse');

const sourcesDir = path.join(__dirname, '../gst_sources');
const manifestPath = path.join(sourcesDir, 'source_manifest.json');

// Read existing manifest to get URLs
let oldManifest = {};
if (fs.existsSync(manifestPath)) {
  oldManifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
}
const items = oldManifest.manifest || [];

const claims = [
  { id: 'CGST_ACT', desc: 'CGST Act', keywords: ['CGST Act', 'Central Goods and Services Tax Act'] },
  { id: 'IGST_ACT', desc: 'IGST Act', keywords: ['IGST Act', 'Integrated Goods and Services Tax Act'] },
  { id: 'UTGST_ACT', desc: 'UTGST Act', keywords: ['UTGST Act', 'Union Territory Goods and Services Tax Act'] },
  { id: 'CESS_ACT', desc: 'Compensation Cess Act', keywords: ['Compensation to States Act'] },
  { id: '31_SGST_5_UTGST', desc: '31 SGST and 5 UTGST Jurisdictions Proof', keywords: ['State Goods and Services Tax'] },
  { id: 'RATE_NOTIF_5_18_40', desc: 'Current Rate Notifications (5%, 18%, 40%)', keywords: ['5%', '18%', '40%'] },
  { id: 'RATE_NOTIF_SPECIAL', desc: 'Special Entry Rates (0.25%, 1.5%, 3%, 12%, 28%)', keywords: ['0.25%', '1.5%', '3%', '12%', '28%'] },
  { id: 'EXEMPT_NOTIF', desc: 'Nil/Exempt Notifications', keywords: ['Nil rated', 'Exempt supply'] },
  { id: 'IGST_16_ZERO_RATED', desc: 'IGST Section 16 Zero-Rated Supplies', keywords: ['Section 16', 'Zero rated supply'] },
  { id: 'IGST_10_13', desc: 'IGST Sections 10-13 Place of Supply', keywords: ['Section 10', 'Section 11', 'Section 12', 'Section 13', 'Place of supply'] },
  { id: 'IGST_14', desc: 'IGST Section 14 OIDAR', keywords: ['Section 14', 'OIDAR'] },
  { id: 'RCM_NOTIF', desc: 'RCM Notifications and Amendments', keywords: ['Reverse charge', '9(3)', '9(4)'] },
  { id: 'COMPOSITION_NOTIF', desc: 'Composition Notifications and Thresholds', keywords: ['Composition', 'Section 10', 'aggregate turnover'] },
  { id: 'CESS_HSNS', desc: 'Separate Compensation Cess and HSNS Cess', keywords: ['Compensation Cess', 'HSN'] }
];

async function getHeaders(url, redirectCount = 0) {
  return new Promise((resolve, reject) => {
    if (redirectCount > 5) return resolve({ status: 302, contentType: 'unknown', finalUrl: url });
    https.get(url, { rejectUnauthorized: false, headers: { 'User-Agent': 'Mozilla/5.0' } }, (res) => {
      if ([301, 302, 303, 307, 308].includes(res.statusCode) && res.headers.location) {
        let newUrl = res.headers.location;
        if (!newUrl.startsWith('http')) {
            const urlObj = new URL(url);
            newUrl = `${urlObj.protocol}//${urlObj.host}${newUrl.startsWith('/') ? '' : '/'}${newUrl}`;
        }
        return resolve(getHeaders(newUrl, redirectCount + 1));
      }
      resolve({ status: res.statusCode, contentType: res.headers['content-type'] || 'unknown', finalUrl: url });
    }).on('error', err => {
      resolve({ status: 'ERROR', contentType: 'unknown', finalUrl: url });
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
  const fileRecords = [];
  const matrix = {};
  claims.forEach(c => matrix[c.id] = { proven: false, document: null, reason: 'UNRESOLVED' });

  for (const item of items) {
    const filepath = path.join(sourcesDir, item.localFile);
    if (!fs.existsSync(filepath)) continue;

    const stats = fs.statSync(filepath);
    const headers = await getHeaders(item.sourceUrl);
    const sha256 = await hashFile(filepath);

    let textContent = '';
    let isForbiddenSubstitute = false;
    
    const lowerName = item.localFile.toLowerCase();
    // Rule: DO NOT USE AN INDEX PAGE, RULES DOCUMENT OR GENERIC HOMEPAGE AS SUBSTITUTE
    if (lowerName.includes('index') || lowerName.includes('rule') || lowerName.includes('homepage') || headers.contentType.includes('text/html')) {
        isForbiddenSubstitute = true;
    }

    if (lowerName.endsWith('.pdf')) {
      try {
        const dataBuffer = fs.readFileSync(filepath);
        const pdfData = await pdfParse(dataBuffer);
        textContent = pdfData.text;
      } catch (e) {
        console.error(`Failed to parse PDF ${item.localFile}: ${e.message}`);
      }
    } else {
      textContent = fs.readFileSync(filepath, 'utf8');
    }

    const record = {
      originalRawUrl: item.sourceUrl,
      finalRedirectedUrl: headers.finalUrl,
      httpStatus: headers.status,
      contentType: headers.contentType,
      byteSize: stats.size,
      exactLocalFilename: item.localFile,
      sha256: sha256,
      documentTitle: item.name, // Approximate since PDF title might be missing
      actNotificationNumber: item.notification || 'UNKNOWN',
      publicationDate: item.publicationDate || 'UNKNOWN',
      effectiveDate: item.effectiveDate || 'UNKNOWN',
      isForbiddenSubstitute: isForbiddenSubstitute,
      supportedClaims: []
    };

    // Attempt to prove claims
    claims.forEach(c => {
      if (matrix[c.id].proven) return; // already proven elsewhere
      
      let found = false;
      for (const kw of c.keywords) {
        if (textContent.includes(kw)) {
          found = true;
          break;
        }
      }

      if (found) {
        if (isForbiddenSubstitute) {
          // Fail the claim because of forbidden document type
          if (!matrix[c.id].failedSubstitutes) matrix[c.id].failedSubstitutes = [];
          matrix[c.id].failedSubstitutes.push(item.localFile);
        } else {
          // Document is not forbidden, wait, is it actually the ACT?
          // If claim is "CGST_ACT" and this is just a notification, it fails.
          const needsAct = c.id.includes('_ACT');
          const isAct = record.actNotificationNumber.includes('Act') || lowerName.includes('act');
          const needsNotif = c.id.includes('NOTIF');
          const isNotif = record.actNotificationNumber.includes('No.') || lowerName.includes('notfcn');
          
          let isValidDocumentType = true;
          if (needsAct && !isAct) isValidDocumentType = false;
          if (needsNotif && !isNotif) isValidDocumentType = false;

          if (isValidDocumentType) {
            matrix[c.id].proven = true;
            matrix[c.id].document = item.localFile;
            matrix[c.id].reason = 'PROVEN';
            record.supportedClaims.push(c.id);
          } else {
            if (!matrix[c.id].failedSubstitutes) matrix[c.id].failedSubstitutes = [];
            matrix[c.id].failedSubstitutes.push(`${item.localFile} (Invalid Doc Type for Claim)`);
          }
        }
      }
    });

    fileRecords.push(record);
  }

  const finalOutput = {
    fileRecords: fileRecords,
    claimCoverageMatrix: matrix
  };

  const outPath = path.join(sourcesDir, 'validation_matrix.json');
  fs.writeFileSync(outPath, JSON.stringify(finalOutput, null, 2));

  console.log(`\n=================================================`);
  console.log(`SOURCE-MANIFEST CONTENT VALIDATION REPORT`);
  console.log(`=================================================`);
  fileRecords.forEach(f => {
    console.log(`\nFILE: ${f.exactLocalFilename}`);
    console.log(`- Original URL: ${f.originalRawUrl}`);
    console.log(`- Final URL: ${f.finalRedirectedUrl}`);
    console.log(`- Status: ${f.httpStatus} | Type: ${f.contentType} | Size: ${f.byteSize} bytes`);
    console.log(`- SHA256: ${f.sha256}`);
    console.log(`- Title: ${f.documentTitle} | Notif/Act: ${f.actNotificationNumber}`);
    console.log(`- Pub Date: ${f.publicationDate} | Eff Date: ${f.effectiveDate}`);
    if (f.isForbiddenSubstitute) {
      console.log(`- STATUS: REJECTED (Forbidden substitute: Index/Rules/HTML)`);
    } else {
      console.log(`- PROVEN CLAIMS: ${f.supportedClaims.join(', ') || 'None'}`);
    }
  });

  console.log(`\n=================================================`);
  console.log(`CLAIM-TO-DOCUMENT COVERAGE MATRIX & GAP CLOSURE`);
  console.log(`=================================================`);
  claims.forEach(c => {
    const status = matrix[c.id];
    if (status.proven) {
      console.log(`[PROVEN] ${c.desc}`);
      console.log(`  -> Source: ${status.document}`);
    } else {
      console.log(`[UNRESOLVED] ${c.desc}`);
      if (status.failedSubstitutes) {
        console.log(`  -> FAILED: Attempted substitutes rejected: ${status.failedSubstitutes.join(', ')}`);
      } else {
        console.log(`  -> FAILED: No matching text found in any downloaded document.`);
      }
    }
  });
}

run();
