/**
 * GST Content Extractor - Phase 2
 * 
 * Key fixes from prior failure:
 * 1. CBIC SPA never hits 'networkidle' (polling/websocket) - use 'domcontentloaded' then wait separately for XHR
 * 2. Intercept XHR/fetch responses via route interception and response listeners
 * 3. Separate PDF fetch via direct HTTPS for indiacode.nic.in
 * 4. gstcouncil.gov.in returns 200 HTML - extract text for SGST/UTGST content
 * 5. All 3067-byte SPA shells are UNRESOLVED
 */
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const https = require('https');

const sourcesDir = path.join(__dirname, '../gst_official_sources_v3');
if (!fs.existsSync(sourcesDir)) fs.mkdirSync(sourcesDir, { recursive: true });

function hashBuffer(buffer) {
  return crypto.createHash('sha256').update(buffer).digest('hex');
}

function isSPAShell(buffer) {
  // The CBIC SPA shell is exactly 3067 bytes with SHA 016d7f4d...
  return buffer.length <= 5000;
}

function downloadDirect(url) {
  return new Promise((resolve) => {
    https.get(url, { rejectUnauthorized: false, headers: { 'User-Agent': 'Mozilla/5.0' } }, (res) => {
      if (res.statusCode !== 200) return resolve({ status: res.statusCode, buffer: null, headers: res.headers, finalUrl: url });
      const chunks = [];
      res.on('data', c => chunks.push(c));
      res.on('end', () => resolve({ status: 200, buffer: Buffer.concat(chunks), headers: res.headers, finalUrl: url }));
    }).on('error', e => resolve({ status: 'ERROR', buffer: null, headers: {}, finalUrl: url, error: e.message }));
  });
}

function validateText(buffer, contentType, keywords) {
  if (!buffer) return { matched: false, evidence: 'No content' };
  let text = '';
  if (contentType.includes('pdf')) {
    // Rudimentary raw byte search - PDFs contain text in streams
    text = buffer.toString('latin1');
  } else {
    text = buffer.toString('utf8');
  }
  const missingKws = keywords.filter(kw => !text.includes(kw));
  if (missingKws.length === 0) {
    return { matched: true, evidence: `All keywords found: ${keywords.join(', ')}` };
  }
  return { matched: false, evidence: `Missing keywords: ${missingKws.join(', ')}` };
}

async function runPlaywrightCapture(browser, claimId, url, keywords, filename) {
  const page = await browser.newPage();
  let bestPayload = null;
  let bestMeta = null;

  page.on('response', async (response) => {
    try {
      const rUrl = response.url();
      const status = response.status();
      const ct = response.headers()['content-type'] || '';
      if (status !== 200) return;
      // Only care about JSON or PDF payloads that are actual data
      if (!ct.includes('application/json') && !ct.includes('application/pdf') && !ct.includes('text/plain')) return;
      const buf = await response.body().catch(() => null);
      if (!buf || buf.length < 1000) return;
      // Prefer larger/more specific payloads
      if (!bestPayload || buf.length > bestPayload.length) {
        bestPayload = buf;
        bestMeta = { responseUrl: rUrl, contentType: ct, status, size: buf.length };
        console.log(`  [XHR captured] ${rUrl} (${buf.length} bytes, ${ct})`);
      }
    } catch (_) {}
  });

  let navStatus = 'ERROR';
  try {
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
    navStatus = 'OK';
    // Wait up to 15s for XHR data to arrive
    await page.waitForTimeout(15000);
  } catch (e) {
    navStatus = e.message;
  }
  await page.close();

  // If we caught a proper XHR payload, use it
  if (bestPayload && !isSPAShell(bestPayload)) {
    const sha256 = hashBuffer(bestPayload);
    const ext = bestMeta.contentType.includes('pdf') ? 'pdf' : 'json';
    const fname = `${filename}.${ext}`;
    fs.writeFileSync(path.join(sourcesDir, fname), bestPayload);
    const { matched, evidence } = validateText(bestPayload, bestMeta.contentType, keywords);
    return {
      method: 'XHR_CAPTURE', navStatus,
      ...bestMeta, localFilename: fname, sha256, matched, evidence
    };
  }

  return { method: 'XHR_CAPTURE', navStatus, status: 'NO_PAYLOAD',
    responseUrl: url, contentType: 'none', size: 0, localFilename: null,
    sha256: null, matched: false, evidence: 'No non-shell payload captured' };
}

async function run() {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ ignoreHTTPSErrors: true });

  const manifest = [];
  const matrix = {};

  // ─── TASK 1: CGST Act Sections 9/10 via CBIC SPA XHR ──────────────────────
  console.log('\n[1] CGST Act 2017 - Sections 9 & 10 (XHR capture)');
  {
    const r = await runPlaywrightCapture(context, 'CGST_9_10',
      'https://taxinformation.cbic.gov.in/view-pdf/1000494/ENG/Acts',
      ['Section 9', 'levy', 'taxable supply'],
      'cgst_sections_9_10');
    matrix['CGST_9_10'] = r.matched ? 'PROVEN' : `UNRESOLVED: ${r.evidence}`;
    manifest.push({ claimId: 'CGST_9_10', title: 'CGST Act 2017 Sections 9 & 10', ...r });
  }

  // ─── TASK 2: IGST Act Sections 10-16 via CBIC SPA XHR ─────────────────────
  console.log('\n[2] IGST Act 2017 - Sections 10-16 (XHR capture)');
  {
    const r = await runPlaywrightCapture(context, 'IGST_10_16',
      'https://taxinformation.cbic.gov.in/view-pdf/1000493/ENG/Acts',
      ['Section 10', 'place of supply', 'Section 14'],
      'igst_sections_10_16');
    matrix['IGST_10_16'] = r.matched ? 'PROVEN' : `UNRESOLVED: ${r.evidence}`;
    manifest.push({ claimId: 'IGST_10_16', title: 'IGST Act 2017 Sections 10-16', ...r });
  }

  await browser.close();

  // ─── TASK 3: SGST Acts - gstcouncil.gov.in/sgst-act ──────────────────────
  console.log('\n[3] 31 SGST Acts - gstcouncil.gov.in/sgst-act (direct HTML)');
  {
    const r = await downloadDirect('https://www.gstcouncil.gov.in/sgst-act');
    let matched = false, evidence = 'HTTP ' + r.status;
    if (r.status === 200 && r.buffer && !isSPAShell(r.buffer)) {
      const text = r.buffer.toString('utf8');
      const kws = ['State Goods and Services Tax', 'SGST'];
      const missing = kws.filter(k => !text.includes(k));
      matched = missing.length === 0;
      evidence = matched ? 'Keywords found: ' + kws.join(', ') : 'Missing: ' + missing.join(', ');
      if (matched || r.buffer.length > 10000) {
        const sha256 = hashBuffer(r.buffer);
        const fname = `sgst_acts_gstcouncil_${sha256.substring(0,8)}.html`;
        fs.writeFileSync(path.join(sourcesDir, fname), r.buffer);
        manifest.push({
          claimId: 'SGST_ACTS', title: '31 SGST Acts',
          method: 'DIRECT_HTTP', responseUrl: r.finalUrl,
          status: r.status, contentType: r.headers['content-type'] || '',
          size: r.buffer.length, localFilename: fname, sha256,
          matched, evidence
        });
        matrix['SGST_ACTS'] = matched ? 'PROVEN' : `UNRESOLVED: ${evidence}`;
      }
    } else {
      manifest.push({ claimId: 'SGST_ACTS', title: '31 SGST Acts', method: 'DIRECT_HTTP',
        responseUrl: r.finalUrl, status: r.status, matched: false, evidence });
      matrix['SGST_ACTS'] = `UNRESOLVED: ${evidence}`;
    }
    console.log(`  status=${r.status} size=${r.buffer ? r.buffer.length : 0} matched=${matched}`);
  }

  // ─── TASK 4: UTGST Act - gstcouncil.gov.in/utgst ─────────────────────────
  console.log('\n[4] UTGST Act - gstcouncil.gov.in/utgst (direct HTML)');
  {
    const r = await downloadDirect('https://www.gstcouncil.gov.in/utgst');
    let matched = false, evidence = 'HTTP ' + r.status;
    if (r.status === 200 && r.buffer && !isSPAShell(r.buffer)) {
      const text = r.buffer.toString('utf8');
      const kws = ['Union Territory Goods and Services Tax', 'UTGST'];
      const missing = kws.filter(k => !text.includes(k));
      matched = missing.length === 0;
      evidence = matched ? 'Keywords found: ' + kws.join(', ') : 'Missing: ' + missing.join(', ');
      const sha256 = hashBuffer(r.buffer);
      const fname = `utgst_gstcouncil_${sha256.substring(0,8)}.html`;
      fs.writeFileSync(path.join(sourcesDir, fname), r.buffer);
      manifest.push({
        claimId: 'UTGST_JURISDICTIONS', title: '5 UTGST Jurisdictions',
        method: 'DIRECT_HTTP', responseUrl: r.finalUrl,
        status: r.status, contentType: r.headers['content-type'] || '',
        size: r.buffer.length, localFilename: fname, sha256,
        matched, evidence
      });
    } else {
      manifest.push({ claimId: 'UTGST_JURISDICTIONS', title: '5 UTGST Jurisdictions', method: 'DIRECT_HTTP',
        responseUrl: r.finalUrl, status: r.status, matched: false, evidence });
    }
    matrix['UTGST_JURISDICTIONS'] = matched ? 'PROVEN' : `UNRESOLVED: ${evidence}`;
    console.log(`  status=${r.status} size=${r.buffer ? r.buffer.length : 0} matched=${matched}`);
  }

  // ─── TASK 5: UTGST Act PDF - indiacode.nic.in ─────────────────────────────
  console.log('\n[5] UTGST Act PDF - indiacode.nic.in');
  {
    const r = await downloadDirect('https://www.indiacode.nic.in/bitstream/123456789/7776/1/ut-gst-act.pdf');
    let matched = false, evidence = 'HTTP ' + r.status;
    if (r.status === 200 && r.buffer && r.buffer.length > 10000) {
      const ct = r.headers['content-type'] || '';
      const text = r.buffer.toString('latin1');
      const kws = ['UTGST', 'Union Territory'];
      const missing = kws.filter(k => !text.includes(k));
      matched = missing.length === 0;
      evidence = matched ? 'Keywords found in PDF: ' + kws.join(', ') : 'Missing: ' + missing.join(', ');
      const sha256 = hashBuffer(r.buffer);
      const fname = `utgst_act_indiacode_${sha256.substring(0,8)}.pdf`;
      fs.writeFileSync(path.join(sourcesDir, fname), r.buffer);
      manifest.push({
        claimId: 'UTGST_ACT_PDF', title: 'UTGST Act PDF (India Code)',
        method: 'DIRECT_HTTP', responseUrl: r.finalUrl,
        status: r.status, contentType: ct,
        size: r.buffer.length, localFilename: fname, sha256,
        matched, evidence
      });
    } else {
      manifest.push({ claimId: 'UTGST_ACT_PDF', title: 'UTGST Act PDF (India Code)', method: 'DIRECT_HTTP',
        responseUrl: r.finalUrl, status: r.status, matched: false, evidence });
    }
    matrix['UTGST_ACT_PDF'] = matched ? 'PROVEN' : `UNRESOLVED: ${evidence}`;
    console.log(`  status=${r.status} size=${r.buffer ? r.buffer.length : 0} matched=${matched}`);
  }

  // ─── TASK 6: GST Rate Table - cbic-gst.gov.in ─────────────────────────────
  console.log('\n[6] HSN/SAC Rate Table - cbic-gst.gov.in (correct path)');
  for (const testUrl of [
    'https://cbic-gst.gov.in/gst-goods-services-rates.html',
    'https://cbic-gst.gov.in/gst-goods-and-services-rates.html',
    'https://cbic-gst.gov.in/goods-services-rates.html'
  ]) {
    const r = await downloadDirect(testUrl);
    console.log(`  ${testUrl} -> ${r.status} (${r.buffer ? r.buffer.length : 0} bytes)`);
    if (r.status === 200 && r.buffer && !isSPAShell(r.buffer)) {
      const sha256 = hashBuffer(r.buffer);
      const fname = `hsn_sac_rate_table_${sha256.substring(0,8)}.html`;
      fs.writeFileSync(path.join(sourcesDir, fname), r.buffer);
      const text = r.buffer.toString('utf8');
      const matched = text.includes('HSN') || text.includes('SAC') || text.includes('Rate');
      manifest.push({
        claimId: 'HSN_SAC_RATE_TABLE', title: 'HSN/SAC Rate Table Cross-check',
        method: 'DIRECT_HTTP', responseUrl: testUrl,
        status: r.status, contentType: r.headers['content-type'] || '',
        size: r.buffer.length, localFilename: fname, sha256,
        matched, evidence: matched ? 'Rate table content found' : 'No rate table content'
      });
      matrix['HSN_SAC_RATE_TABLE'] = matched ? 'PROVEN' : `UNRESOLVED: No rate content`;
      break;
    }
    matrix['HSN_SAC_RATE_TABLE'] = `UNRESOLVED: all paths 404/shell`;
  }

  // ─── Write final manifest ─────────────────────────────────────────────────
  const outPath = path.join(sourcesDir, 'extraction_report.json');
  fs.writeFileSync(outPath, JSON.stringify({ manifest, matrix }, null, 2));

  console.log('\n\n=================================================');
  console.log('SOURCE MANIFEST — ACTUAL CONTENT PAYLOADS');
  console.log('=================================================');
  for (const m of manifest) {
    const status = m.matched ? '✅ PROVEN' : '❌ UNRESOLVED';
    console.log(`\n[${m.claimId}] ${m.title}`);
    console.log(`  Status: ${status}`);
    console.log(`  URL: ${m.responseUrl || 'N/A'}`);
    console.log(`  HTTP: ${m.status} | Type: ${m.contentType || 'N/A'} | Size: ${m.size || 0} bytes`);
    if (m.sha256) console.log(`  SHA256: ${m.sha256}`);
    if (m.localFilename) console.log(`  File: ${m.localFilename}`);
    console.log(`  Evidence: ${m.evidence || 'N/A'}`);
  }

  console.log('\n\n=================================================');
  console.log('CORRECTED CLAIM MATRIX (FAILURES MARKED UNRESOLVED)');
  console.log('=================================================');
  for (const [claimId, status] of Object.entries(matrix)) {
    console.log(`[${status.startsWith('PROVEN') ? 'PROVEN   ' : 'UNRESOLVED'}] ${claimId}: ${status}`);
  }
}

run().catch(e => { console.error('Fatal:', e); process.exit(1); });
