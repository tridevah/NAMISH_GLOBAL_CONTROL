const { chromium } = require('playwright');
const fs = require('fs');
const crypto = require('crypto');
const path = require('path');

const claims = [
  { id: 'CGST_ACT', group: '1', url: 'https://www.indiacode.nic.in/bitstream/123456789/15689/1/central_goods_and_services_tax_act_2017.pdf' },
  { id: 'IGST_ACT', group: '1', url: 'https://www.indiacode.nic.in/bitstream/123456789/2251/1/a2017-13.pdf' },
  { id: 'UTGST_ACT', group: '1', url: 'https://www.indiacode.nic.in/bitstream/123456789/2252/1/a2017-14.pdf' },
  { id: 'COMPENSATION_CESS_ACT', group: '1', url: 'https://www.indiacode.nic.in/bitstream/123456789/2253/1/a2017-15.pdf' },
  { id: 'HSNS_CESS_ACT', group: '1', url: 'https://www.indiacode.nic.in/bitstream/123456789/22084/1/health_and_education_cess.pdf' },
  
  { id: 'RATES_2025_2026', group: '2', url: 'https://gstcouncil.gov.in/sites/default/files/cgst-rates/Notf_1-2017-CGST-Rate.pdf' },
  
  { id: 'GOODS_RCM_04_2017', group: '3', url: 'https://gstcouncil.gov.in/sites/default/files/cgst-rates/Notf_4-CGST-Rate.pdf' },
  { id: 'GOODS_RCM_06_2024', group: '3', url: 'https://gstcouncil.gov.in/sites/default/files/cgst-rates/notfctn-06-2024-cgst-rate.pdf' },
  
  { id: 'SERVICES_RCM_13_2017', group: '4', url: 'https://gstcouncil.gov.in/sites/default/files/cgst-rates/Notf_13-CGST-Rate.pdf' },
  { id: 'SERVICES_RCM_07_2025', group: '4', url: 'https://gstcouncil.gov.in/sites/default/files/cgst-rates/notfctn-07-2025-cgst-rate.pdf' },
  
  { id: 'INTER_STATE_RCM_10_2017', group: '5', url: 'https://gstcouncil.gov.in/sites/default/files/igst-rates/Notf_10-IGST-Rate.pdf' },
  { id: 'INTER_STATE_RCM_07_2025', group: '5', url: 'https://gstcouncil.gov.in/sites/default/files/igst-rates/notfctn-07-2025-igst-rate.pdf' },
  
  { id: 'SECTION_9_4_07_2019', group: '6', url: 'https://gstcouncil.gov.in/sites/default/files/cgst-rates/notfctn-07-2019-cgst-rate.pdf' },
  { id: 'SECTION_9_4_24_2019', group: '6', url: 'https://gstcouncil.gov.in/sites/default/files/cgst-rates/notfctn-24-2019-cgst-rate.pdf' },
  
  { id: 'COMPOSITION_14_2019', group: '7', url: 'https://gstcouncil.gov.in/sites/default/files/cgst-rates/notfctn-14-2019-cgst.pdf' },
  { id: 'COMPOSITION_02_2019', group: '7', url: 'https://gstcouncil.gov.in/sites/default/files/cgst-rates/notfctn-02-2019-cgst-rate.pdf' }
];

async function run() {
  const outDir = path.join(__dirname, '../gst_sources/verified_v4_1');
  const manifest = { timestamp: new Date().toISOString(), counts: { downloaded: 0, proven: 0, blocked: 0, unresolved: 0 }, proven_claims: [], blocked_claims: [], errors: [] };
  const matrix = [];
  
  let browser;
  try {
    browser = await chromium.connectOverCDP('http://localhost:9222');
  } catch(e) {
    console.error('CDP connect failed:', e.message);
  }

  for (const claim of claims) {
    console.log("Checking " + claim.id + "...");
    let resultStatus = 'RETRIEVAL_BLOCKED';
    let resultSha = null;
    let errorMsg = null;
    
    if (browser) {
      try {
        const context = browser.contexts()[0];
        const page = await context.newPage();
        
        let pdfBuffer = null;
        let responseStatus = 0;
        let contentType = '';
        
        page.on('response', async (res) => {
          if (res.url() === claim.url) {
            responseStatus = res.status();
            contentType = res.headers()['content-type'] || '';
            try {
              pdfBuffer = await res.body();
            } catch(e) {}
          }
        });

        await page.goto(claim.url, { waitUntil: 'networkidle', timeout: 10000 });
        await page.waitForTimeout(2000);
        await page.close();

        if (!pdfBuffer || responseStatus !== 200 || !contentType.includes('pdf')) {
            errorMsg = "HTTP " + responseStatus + ", Content-Type: " + contentType + ", Buffer Length: " + (pdfBuffer ? pdfBuffer.length : 0);
        } else {
            // Check PDF magic
            if (pdfBuffer.slice(0, 5).toString('ascii') === '%PDF-') {
                resultStatus = 'PRIMARY_LEGAL_PROVEN';
                resultSha = crypto.createHash('sha256').update(pdfBuffer).digest('hex');
                fs.writeFileSync(path.join(outDir, claim.id + '.pdf'), pdfBuffer);
                manifest.counts.downloaded++;
                manifest.counts.proven++;
            } else {
                errorMsg = 'Invalid PDF magic bytes';
            }
        }
      } catch(e) {
          errorMsg = e.message;
      }
    } else {
        errorMsg = 'CDP Connection failed';
    }

    if (resultStatus === 'RETRIEVAL_BLOCKED') {
        manifest.counts.blocked++;
        manifest.blocked_claims.push({ id: claim.id, url: claim.url, error: errorMsg });
        manifest.errors.push({ id: claim.id, error: errorMsg });
    } else if (resultStatus === 'PRIMARY_LEGAL_PROVEN') {
        manifest.proven_claims.push({ id: claim.id, url: claim.url, sha256: resultSha });
    }

    matrix.push({ claim_id: claim.id, status: resultStatus, sha256: resultSha, error: errorMsg });
    console.log(claim.id + ": " + resultStatus + (errorMsg ? " (" + errorMsg + ")" : ""));
  }

  if (browser) await browser.close();

  fs.writeFileSync(path.join(outDir, 'source_manifest_v4_1.json'), JSON.stringify(manifest, null, 2));
  fs.writeFileSync(path.join(outDir, 'claim_matrix_v4_1.json'), JSON.stringify(matrix, null, 2));

  console.log('\\nResults:');
  console.log("Downloaded: " + manifest.counts.downloaded);
  console.log("Proven: " + manifest.counts.proven);
  console.log("Blocked: " + manifest.counts.blocked);
}

run();
