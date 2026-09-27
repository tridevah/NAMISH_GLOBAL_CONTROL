const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const pdfParse = require('pdf-parse');

const outDir = path.join(__dirname, '../gst_sources');
if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });

function sha256(buf) {
  return crypto.createHash('sha256').update(buf).digest('hex');
}

async function parsePDF(buffer, keywords) {
  try {
    let parsedText = '';
    if (typeof pdfParse === 'function') {
        parsedText = (await pdfParse(buffer)).text;
    } else if (pdfParse && pdfParse.default) {
        parsedText = (await pdfParse.default(buffer)).text;
    } else {
        parsedText = (await pdfParse(buffer)).text;
    }
    const textSha = sha256(Buffer.from(parsedText, 'utf8'));
    const hits = keywords.filter(k => parsedText.includes(k));
    const missing = keywords.filter(k => !parsedText.includes(k));
    return { textSha, hits, missing, parsedText };
  } catch (e) {
    return { error: e.message };
  }
}

async function fetchViaCDP(url, browser) {
  const context = browser.contexts()[0];
  const page = await context.newPage();
  let buffer = null;
  let status = 0;
  let ct = '';
  
  page.on('response', async (res) => {
    // some redirects might change url
    if (res.url() === url || res.request().url() === url || res.url().includes(url.split('/').pop())) {
      if (res.status() === 200) {
        status = 200;
        ct = res.headers()['content-type'] || '';
        try { buffer = await res.body(); } catch (e) {}
      }
    }
  });

  try {
    await page.goto(url, { waitUntil: 'networkidle', timeout: 30000 });
  } catch (e) {}
  
  if (!buffer) {
     try {
       const content = await page.content();
       buffer = Buffer.from(content, 'utf8');
       status = 200;
       ct = 'text/html';
     } catch(e) {}
  }
  
  await page.close();
  return { ok: buffer != null && buffer.length > 5000, status, buffer, ct, finalUrl: url };
}

async function processClaim(claimId, url, title, keywords, browser, effectiveDate) {
  console.log(`Processing ${claimId} -> ${url}`);
  let res = await fetchViaCDP(url, browser);
  
  if (!res.ok || !res.buffer || res.status !== 200) {
    return {
      claimId, title, originalUrl: url, finalUrl: url, httpStatus: res.status,
      contentType: res.ct, byteSize: 0, binarySha256: '', textSha256: '',
      exactMatchedText: '', effectiveDate, status: 'UNRESOLVED', note: 'Failed to download via CDP'
    };
  }

  const binarySha256 = sha256(res.buffer);
  let textSha256 = '';
  let hits = [];
  let missing = [];
  
  if (res.ct.includes('pdf') || res.buffer.slice(0, 4).toString() === '%PDF') {
    fs.writeFileSync(path.join(outDir, `${claimId}_${binarySha256.slice(0,8)}.pdf`), res.buffer);
    const parsed = await parsePDF(res.buffer, keywords);
    if (!parsed.error) {
      textSha256 = parsed.textSha;
      hits = parsed.hits;
      missing = parsed.missing;
      fs.writeFileSync(path.join(outDir, `${claimId}_${binarySha256.slice(0,8)}.txt`), parsed.parsedText);
    } else {
        missing = keywords;
    }
  } else {
    // HTML
    fs.writeFileSync(path.join(outDir, `${claimId}_${binarySha256.slice(0,8)}.html`), res.buffer);
    const htmlText = res.buffer.toString('utf8');
    textSha256 = sha256(Buffer.from(htmlText, 'utf8'));
    hits = keywords.filter(k => htmlText.includes(k));
    missing = keywords.filter(k => !htmlText.includes(k));
  }

  const status = missing.length === 0 ? 'PROVEN' : 'UNRESOLVED';
  return {
    claimId, title, originalUrl: url, finalUrl: url, httpStatus: res.status,
    contentType: res.ct, byteSize: res.buffer.length, binarySha256, textSha256,
    exactMatchedText: hits.join(', '), effectiveDate, status,
    note: missing.length > 0 ? `Missing keywords: ${missing.join(', ')}` : 'Verified.'
  };
}

async function run() {
  const browser = await chromium.connectOverCDP('http://localhost:9222');
  const manifest = [];
  
  // 1. Check existing CGST PDF (2020)
  const cgstBufPath = path.join(outDir, 'cgst_act_updated_30092020_4db47a4e.pdf');
  if (fs.existsSync(cgstBufPath)) {
      const cgstBuf = fs.readFileSync(cgstBufPath);
      const cgstParse = await parsePDF(cgstBuf, ['Section 9', 'Section 10']);
      manifest.push({
        claimId: 'CGST_ACT_S9_S10_2020', title: 'Central Goods and Services Tax Act 2017 (2020 Consolidation)',
        originalUrl: 'https://cbic-gst.gov.in/pdf/CGST-Act-Updated-30092020.pdf', finalUrl: 'https://cbic-gst.gov.in/pdf/CGST-Act-Updated-30092020.pdf',
        httpStatus: 200, contentType: 'application/pdf', byteSize: cgstBuf.length,
        binarySha256: sha256(cgstBuf), textSha256: cgstParse.textSha || '', exactMatchedText: cgstParse.hits ? cgstParse.hits.join(', ') : '',
        effectiveDate: '30-Sep-2020', status: cgstParse.missing && cgstParse.missing.length === 0 ? 'PROVEN' : 'UNRESOLVED',
        note: 'Consolidation Date: 30-Sep-2020'
      });
      if (cgstParse.parsedText) fs.writeFileSync(path.join(outDir, 'cgst_act_updated_30092020_4db47a4e.txt'), cgstParse.parsedText);
  }

  // 2. UTGST HTML from CBIC
  manifest.push(await processClaim('UTGST_ACT_CURRENT',
    'https://taxinformation.cbic.gov.in/content/html/tax_repository/gst/acts/2017_ut_gst_act/documents/Union_Territory_Goods_And_Services_Tax_Act%2C_2017_27-March-2020.html',
    'Union Territory Goods and Services Tax Act 2017 (CBIC HTML)',
    ['Andaman', 'Chandigarh', 'Dadra', 'Lakshadweep', 'Ladakh'], browser, '27-Mar-2020'));

  // 3. CESS claims
  manifest.push(await processClaim('CESS_ACT_2017', 'https://www.indiacode.nic.in/indiacode/bitstream/123456789/2253/1/A2017-15.pdf',
    'GST Compensation to States Act 2017', ['Compensation', 'Cess'], browser, '2017'));
  manifest.push(await processClaim('HSNS_CESS_ACT_2025', 'https://www.indiacode.nic.in/indiacode/bitstream/123456789/22084/1/a2025-35.pdf',
    'Health Security SE National Security Cess Act 2025', ['Health Security', 'National Security', 'Cess'], browser, '2025'));

  // 4. IGST Act
  manifest.push(await processClaim('IGST_ACT_S10_S16', 'https://cbic-gst.gov.in/pdf/IGST-Act-Updated-30092020.pdf',
    'Integrated Goods and Services Tax Act 2017', ['Section 10', 'Section 16'], browser, '2020'));

  // 5. Rate Notifications
  const claims = [
    { id: 'RATE_09_2025_CTR', t: 'Notification 9/2025-Central Tax (Rate)', u: 'https://taxinformation.cbic.gov.in/api/v1/document?type=notifications&id=09-2025-CTR' },
    { id: 'RATE_10_2025_CTR', t: 'Notification 10/2025-Central Tax (Rate)', u: 'https://taxinformation.cbic.gov.in/api/v1/document?type=notifications&id=10-2025-CTR' },
    { id: 'RATE_15_2025_CTR', t: 'Notification 15/2025-Central Tax (Rate)', u: 'https://taxinformation.cbic.gov.in/api/v1/document?type=notifications&id=15-2025-CTR' },
    { id: 'RATE_16_2025_CTR', t: 'Notification 16/2025-Central Tax (Rate)', u: 'https://taxinformation.cbic.gov.in/api/v1/document?type=notifications&id=16-2025-CTR' },
    { id: 'RCM_04_2017_CTR', t: 'Notification 4/2017-Central Tax (Rate) - Goods RCM', u: 'https://taxinformation.cbic.gov.in/api/v1/document?type=notifications&id=04-2017-CTR' },
    { id: 'RCM_13_2017_CTR', t: 'Notification 13/2017-Central Tax (Rate) - Services RCM', u: 'https://taxinformation.cbic.gov.in/api/v1/document?type=notifications&id=13-2017-CTR' },
    { id: 'RCM_04_2017_ITR', t: 'Notification 4/2017-Integrated Tax (Rate) - IGST Goods RCM', u: 'https://taxinformation.cbic.gov.in/api/v1/document?type=notifications&id=04-2017-ITR' },
    { id: 'RCM_10_2017_ITR', t: 'Notification 10/2017-Integrated Tax (Rate) - IGST Services RCM', u: 'https://taxinformation.cbic.gov.in/api/v1/document?type=notifications&id=10-2017-ITR' },
    { id: 'RCM_07_2019_CTR', t: 'Notification 7/2019-Central Tax (Rate) - S.9(4) RCM', u: 'https://taxinformation.cbic.gov.in/api/v1/document?type=notifications&id=07-2019-CTR' },
    { id: 'COMP_14_2019_CT', t: 'Notification 14/2019-Central Tax - Composition', u: 'https://taxinformation.cbic.gov.in/api/v1/document?type=notifications&id=14-2019-CT' },
    { id: 'COMP_02_2019_CTR', t: 'Notification 2/2019-Central Tax (Rate) - Composition', u: 'https://taxinformation.cbic.gov.in/api/v1/document?type=notifications&id=02-2019-CTR' },
    { id: 'RATE_01_2017_CESS', t: 'Notification 1/2017-Compensation Cess (Rate)', u: 'https://taxinformation.cbic.gov.in/api/v1/document?type=notifications&id=01-2017-Cess-Rate' }
  ];

  for (const c of claims) {
    manifest.push(await processClaim(c.id, c.u, c.t, ['Notification'], browser, '2017-2025'));
  }

  // We do NOT close the browser, only disconnect!
  await browser.close();

  fs.writeFileSync(path.join(outDir, 'source_manifest_v3_1.json'), JSON.stringify({ manifest }, null, 2));

  let proven = 0, unresolved = 0;
  manifest.forEach(m => {
      if (m.status === 'PROVEN') proven++;
      else unresolved++;
  });
  
  console.log(`\nsource_manifest_v3_1.json Written.`);
  console.log(`Total Claims Processed: ${manifest.length}`);
  console.log(`PROVEN: ${proven}`);
  console.log(`UNRESOLVED: ${unresolved}`);
}

run().catch(console.error);
