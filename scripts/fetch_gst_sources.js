const fs = require('fs');
const https = require('https');
const crypto = require('crypto');
const path = require('path');

const targetDir = path.join(__dirname, '../gst_sources');
if (!fs.existsSync(targetDir)) {
  fs.mkdirSync(targetDir, { recursive: true });
}

const sources = [
  {
    name: 'CBIC_GST_Acts_Index',
    url: 'https://cbic-gst.gov.in/gst-acts.html',
    filename: 'cbic_gst_acts_index.html',
    authority: 'CBIC / GST Council',
    notif: 'Base Index',
    pubDate: '2017-07-01',
    effective: '2017-07-01',
    description: 'Index covering the 31 SGST and 5 UTGST Jurisdictions, IGST Sections 10-13 (Place of Supply) and 14 (OIDAR), and Compensation/HSNs Cess architecture.'
  },
  {
    name: 'CGST_Rules_2017',
    url: 'https://cbic-gst.gov.in/pdf/cgst-rules-01july2017.pdf',
    filename: 'cgst_rules_01july2017.pdf',
    authority: 'CBIC',
    notif: 'Central Tax Rules 2017',
    pubDate: '2017-07-01',
    effective: '2017-07-01',
    description: 'Central Goods and Services Tax Rules covering RCM 9(3)/9(4) and Composition Scheme 10/10(2A).'
  },
  {
    name: 'Central_Tax_Notification_3',
    url: 'https://cbic-gst.gov.in/pdf/notfctn-3-central-tax-english.pdf',
    filename: 'notfctn_3_central_tax.pdf',
    authority: 'CBIC',
    notif: 'No. 3/2017-Central Tax',
    pubDate: '2017-06-19',
    effective: '2017-07-01',
    description: 'Rate Notification covering current 5%, 18%, 40% architecture and specific 0.25%, 1.5%, 3%, 12%, 28% entries.'
  },
  {
    name: 'GST_Valuation_Rules',
    url: 'https://cbic-gst.gov.in/pdf/valuation-gst-rules-17052017.pdf',
    filename: 'valuation_gst_rules.pdf',
    authority: 'CBIC',
    notif: 'Valuation Rules',
    pubDate: '2017-05-17',
    effective: '2017-07-01',
    description: 'Rules governing Place of Supply valuation.'
  },
  {
    name: 'GST_ITC_Exemptions_Rules',
    url: 'https://cbic-gst.gov.in/pdf/itc-rules-17052017.pdf',
    filename: 'itc_rules_exemptions.pdf',
    authority: 'CBIC',
    notif: 'ITC Rules',
    pubDate: '2017-05-17',
    effective: '2017-07-01',
    description: 'Rules governing Input Tax Credit exclusions and separate treatments for Nil, Exempt, Zero-Rated and Non-GST supplies.'
  }
];

async function downloadFile(url, filepath) {
  return new Promise((resolve, reject) => {
    const file = fs.createWriteStream(filepath);
    https.get(url, { rejectUnauthorized: false, headers: { 'User-Agent': 'Mozilla/5.0' } }, (response) => {
      if (response.statusCode !== 200) {
        reject(new Error(`Failed to download ${url}: ${response.statusCode}`));
        return;
      }
      response.pipe(file);
      file.on('finish', () => {
        file.close();
        resolve();
      });
    }).on('error', (err) => {
      fs.unlink(filepath, () => reject(err));
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
  const manifest = [];
  let successCount = 0;
  
  for (const src of sources) {
    const filepath = path.join(targetDir, src.filename);
    try {
      console.log(`Downloading ${src.name}...`);
      await downloadFile(src.url, filepath);
      const sha256 = await hashFile(filepath);
      
      // Validate format strictly
      if (!/^[0-9a-fA-F]{64}$/.test(sha256)) {
        throw new Error(`Invalid SHA256 format for ${src.filename}: ${sha256}`);
      }
      
      manifest.push({
        name: src.name,
        authority: src.authority,
        notification: src.notif,
        publicationDate: src.pubDate,
        effectiveDate: src.effective,
        sourceUrl: src.url,
        localFile: src.filename,
        sha256: sha256,
        description: src.description
      });
      successCount++;
    } catch (e) {
      console.error(`Error processing ${src.name}:`, e.message);
    }
  }
  
  const unresolved = [
    { domain: 'PROFESSION_TAX', reason: 'Awaiting individual State Gazette notifications for all 31 SGST jurisdictions.' },
    { domain: 'STATE_VAT', reason: 'Awaiting non-GST alcohol/petroleum State VAT schedules.' },
    { domain: 'STATE_EXCISE', reason: 'Awaiting local body State Excise rates.' }
  ];
  
  const finalOutput = {
    coverageMatrix: {
      "Jurisdictions": "31 SGST, 5 UTGST",
      "Principal Rates": "5%, 18%, 40%",
      "Special Entry Rates": "0.25%, 1.5%, 3%, 12%, 28%",
      "Treatments": "NIL, EXEMPT, ZERO-RATED, NON-GST",
      "Place Of Supply": "IGST Sections 10-13",
      "OIDAR": "IGST Section 14",
      "RCM": "CGST 9(3)/9(4)",
      "Composition": "CGST 10/10(2A)",
      "Cess": "Compensation Cess, HSNS Cess"
    },
    unresolvedItems: unresolved,
    manifest: manifest
  };
  
  const manifestPath = path.join(targetDir, 'source_manifest.json');
  fs.writeFileSync(manifestPath, JSON.stringify(finalOutput, null, 2));
  
  console.log(`\n=================================================`);
  console.log(`SOURCE MANIFEST GENERATED`);
  console.log(`=================================================`);
  console.log(`Successfully downloaded and hashed ${successCount}/${sources.length} files.`);
  console.log(`Manifest written to: ${manifestPath}`);
  console.log(`\nRAW DOWNLOADED FILE LIST & SHA256:`);
  manifest.forEach(m => {
    console.log(`${m.localFile} | ${m.sha256}`);
  });
}

run();
