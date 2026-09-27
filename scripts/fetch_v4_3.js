const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { execSync } = require('child_process');
const pdf = require('pdf-parse');

const outDir = path.join(__dirname, '../gst_sources/verified_v4_3');

const targets = [
  { url: 'https://egazette.gov.in/WriteReadData/2025/266209.pdf', ref: 'https://egazette.gov.in', name: 'egazette_266209.pdf' },
  { url: 'https://egazette.gov.in/WriteReadData/2025/266219.pdf', ref: 'https://egazette.gov.in', name: 'egazette_266219.pdf' },
  { url: 'https://egazette.gov.in/WriteReadData/2025/266246.pdf', ref: 'https://egazette.gov.in', name: 'egazette_266246.pdf' },
  { url: 'https://egazette.gov.in/WriteReadData/2025/268974.pdf', ref: 'https://egazette.gov.in', name: 'egazette_268974.pdf' },
  { url: 'https://egazette.gov.in/WriteReadData/2026/272190.pdf', ref: 'https://egazette.gov.in', name: 'egazette_272190.pdf' },
  { url: 'https://gstcouncil.gov.in/sites/default/files/2024-05/download_8_0.pdf', ref: 'https://gstcouncil.gov.in', name: 'gst_download_8_0.pdf' },
  { url: 'https://gstcouncil.gov.in/sites/default/files/2024-05/13reverse_charge_cgst_corrigendum.pdf', ref: 'https://gstcouncil.gov.in', name: 'gst_13reverse_charge_corrigendum.pdf' },
  { url: 'https://gstcouncil.gov.in/sites/default/files/2024-05/notfctn-14-central-tax-english-2019.pdf', ref: 'https://gstcouncil.gov.in', name: 'gst_notfctn-14-2019.pdf' },
  { url: 'https://gstcouncil.gov.in/sites/default/files/2024-05/download_2024-05-17t161230.215.pdf', ref: 'https://gstcouncil.gov.in', name: 'gst_download_2024-05-17.pdf' }
];

async function run() {
  const manifest = { timestamp: new Date().toISOString(), downloaded_bundles: 0, extracted_notifications: 0 };
  const extracted = [];
  const failures = [];

  // Carry over the smoke test
  const smokePath = path.join(outDir, '04-2017-CTR.pdf');
  if (fs.existsSync(smokePath)) {
      const buf = fs.readFileSync(smokePath);
      const sha256 = crypto.createHash('sha256').update(buf).digest('hex');
      manifest.downloaded_bundles++;
      
      try {
        const data = await pdf(buf);
        extracted.push({
            file: '04-2017-CTR.pdf',
            sha256,
            pages: data.numpages,
            notifications: ['04/2017-Central Tax (Rate)']
        });
        manifest.extracted_notifications++;
      } catch(e) {}
  }

  for (const t of targets) {
    console.log(`Downloading ${t.name}...`);
    try {
        execSync(`curl.exe -L --fail --retry 3 -A "Mozilla/5.0" -e "${t.ref}" "${t.url}" -o "${path.join(outDir, t.name)}"`, { stdio: 'ignore' });
        
        const buf = fs.readFileSync(path.join(outDir, t.name));
        const magic = buf.slice(0, 5).toString('ascii');
        if (magic !== '%PDF-') {
            throw new Error('Invalid PDF magic signature');
        }

        manifest.downloaded_bundles++;
        const sha256 = crypto.createHash('sha256').update(buf).digest('hex');
        
        const data = await pdf(buf);
        const text = data.text;
        
        // Find notification numbers like "No. 13/2017-Central Tax" or "No. 14/2019-Central" or "10/2017-Integrated"
        // Also "G.S.R." or "No. 09/2025" etc.
        const notifRegex = /(?:Notification)?\s*No\.?\s*(\d+\/\d{4}(?:-[A-Za-z\s\(\)]+)?)/gi;
        let match;
        const found = new Set();
        while ((match = notifRegex.exec(text)) !== null) {
            found.add(match[1].trim());
        }

        // Just in case we didn't find specific format, try to find G.S.R
        const gsrRegex = /G\.?S\.?R\.?\s*(\d+[E]?\([E]?\))/gi;
        while ((match = gsrRegex.exec(text)) !== null) {
            found.add("G.S.R. " + match[1].trim());
        }

        const notifs = Array.from(found);
        manifest.extracted_notifications += notifs.length;

        extracted.push({
            file: t.name,
            sha256,
            pages: data.numpages,
            notifications: notifs,
            preview: text.substring(0, 200).replace(/\s+/g, ' ')
        });

    } catch (e) {
        failures.push({ url: t.url, error: e.message });
        console.log(`Failed: ${t.url} - ${e.message}`);
    }
  }

  fs.writeFileSync(path.join(outDir, 'source_manifest_v4_3.json'), JSON.stringify(manifest, null, 2));
  fs.writeFileSync(path.join(outDir, 'extracted_instruments_v4_3.json'), JSON.stringify(extracted, null, 2));
  fs.writeFileSync(path.join(outDir, 'retrieval_failures_v4_3.json'), JSON.stringify(failures, null, 2));

  console.log('\n--- V4.3 SUMMARY ---');
  console.log('Downloaded bundles:', manifest.downloaded_bundles);
  console.log('Extracted notifications:', manifest.extracted_notifications);
  console.log('Failures:', failures.length);
}

run();
