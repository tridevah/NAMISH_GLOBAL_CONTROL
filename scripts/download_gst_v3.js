/**
 * GST Source V3 Final Downloader
 * Downloads ONLY the two confirmed binary URLs, hashes them, validates text content.
 * Compiles the complete, authoritative UNRESOLVED list for everything else.
 */
const https = require('https');
const http  = require('http');
const fs    = require('fs');
const path  = require('path');
const crypto = require('crypto');

const outDir = path.join(__dirname, '../gst_sources');
if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });

function download(url) {
  return new Promise((resolve, reject) => {
    const mod = url.startsWith('https') ? https : http;
    const chunks = [];
    const finalHeaders = {};
    let finalUrl = url;
    let finalStatus = 0;

    function get(u, hops) {
      if (hops > 5) return reject(new Error('Too many redirects'));
      mod.get(u, { rejectUnauthorized: false,
        headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' },
        timeout: 30000 }, res => {
        finalStatus = res.statusCode;
        Object.assign(finalHeaders, res.headers);
        if ([301,302,303,307,308].includes(res.statusCode) && res.headers.location) {
          let loc = res.headers.location;
          if (!loc.startsWith('http')) { const p = new URL(u); loc = p.origin + (loc.startsWith('/') ? loc : '/' + loc); }
          finalUrl = loc;
          res.destroy();
          return get(loc, hops + 1);
        }
        if (res.statusCode !== 200) {
          res.destroy();
          return resolve({ ok: false, status: res.statusCode, finalUrl: u, headers: res.headers, buffer: null });
        }
        res.on('data', c => chunks.push(c));
        res.on('end', () => resolve({ ok: true, status: 200, finalUrl, headers: finalHeaders, buffer: Buffer.concat(chunks) }));
        res.on('error', reject);
      }).on('error', e => resolve({ ok: false, status: 'ERR', finalUrl: u, headers: {}, buffer: null, error: e.message }));
    }
    get(url, 0);
  });
}

function sha256(buf) { return crypto.createHash('sha256').update(buf).digest('hex'); }

// Rudimentary PDF text search (raw bytes contain text in PDF streams)
function pdfContains(buf, terms) {
  const raw = buf.toString('latin1');
  return terms.filter(t => raw.includes(t));
}

async function run() {
  const timestamp = new Date().toISOString();
  const manifest = [];

  // ── 1. CGST Act (Confirmed 200, 1846889 bytes) ──────────────────────────────
  console.log('[1/2] Downloading CGST Act PDF...');
  const cgst = await download('https://cbic-gst.gov.in/pdf/CGST-Act-Updated-30092020.pdf');
  if (cgst.ok) {
    const h = sha256(cgst.buffer);
    const fname = `cgst_act_updated_30092020_${h.slice(0,8)}.pdf`;
    fs.writeFileSync(path.join(outDir, fname), cgst.buffer);
    const hits = pdfContains(cgst.buffer, ['Section 9', 'Section 10', 'levy', 'taxable supply',
      'reverse charge', 'composition', 'Sections 10']);
    manifest.push({
      claimId: 'CGST_ACT_S9_S10',
      documentTitle: 'Central Goods and Services Tax Act 2017 (Consolidated to 30-Sep-2020)',
      authority: 'CBIC',
      notificationRef: 'CGST Act 2017 as amended',
      originalUrl: 'https://cbic-gst.gov.in/pdf/CGST-Act-Updated-30092020.pdf',
      finalUrl: cgst.finalUrl,
      httpStatus: cgst.status,
      contentType: cgst.headers['content-type'] || 'application/pdf',
      byteSize: cgst.buffer.length,
      localFile: fname,
      sha256: h,
      retrievedAt: timestamp,
      legalTextTermsFound: hits,
      legalTextTermsMissing: ['Section 9', 'Section 10', 'levy', 'taxable supply',
        'reverse charge', 'composition'].filter(t => !hits.includes(t)),
      verdict: hits.includes('Section 9') && hits.includes('Section 10') ? 'PROVEN' : 'UNRESOLVED'
    });
    console.log(`   SHA256: ${h}`);
    console.log(`   Terms found: ${hits.join(', ')}`);
  } else {
    manifest.push({ claimId:'CGST_ACT_S9_S10', verdict:'UNRESOLVED', reason:`HTTP ${cgst.status}` });
  }

  // ── 2. UTGST Act (Confirmed 200, 529649 bytes at indiacode) ─────────────────
  console.log('[2/2] Downloading UTGST Act PDF...');
  const utgst = await download('https://www.indiacode.nic.in/bitstream/123456789/7776/1/ut-gst-act.pdf');
  if (utgst.ok) {
    const h = sha256(utgst.buffer);
    const fname = `utgst_act_indiacode_${h.slice(0,8)}.pdf`;
    fs.writeFileSync(path.join(outDir, fname), utgst.buffer);
    const hits = pdfContains(utgst.buffer, ['UTGST', 'Union Territory', 'Andaman', 'Chandigarh',
      'Dadra', 'Lakshadweep', 'Ladakh', 'Section 7', 'levy']);
    manifest.push({
      claimId: 'UTGST_ACT_JURISDICTIONS',
      documentTitle: 'The Union Territory Goods and Services Tax Act, 2017',
      authority: 'India Code / Ministry of Law',
      notificationRef: 'UTGST Act 2017',
      originalUrl: 'https://www.indiacode.nic.in/bitstream/123456789/7776/1/ut-gst-act.pdf',
      finalUrl: utgst.finalUrl,
      httpStatus: utgst.status,
      contentType: utgst.headers['content-type'] || 'application/pdf',
      byteSize: utgst.buffer.length,
      localFile: fname,
      sha256: h,
      retrievedAt: timestamp,
      legalTextTermsFound: hits,
      legalTextTermsMissing: ['UTGST','Union Territory','Andaman','Chandigarh','Dadra','Lakshadweep','Ladakh']
        .filter(t => !hits.includes(t)),
      verdict: hits.includes('Union Territory') && hits.length >= 3 ? 'PROVEN' : 'UNRESOLVED'
    });
    console.log(`   SHA256: ${h}`);
    console.log(`   Terms found: ${hits.join(', ')}`);
  } else {
    manifest.push({ claimId:'UTGST_ACT_JURISDICTIONS', verdict:'UNRESOLVED', reason:`HTTP ${utgst.status}` });
  }

  // ── 3. Everything else — UNRESOLVED with exact probe evidence ────────────────
  const unresolvedFamilies = [
    { claimId: 'IGST_ACT_S10_16', needed: 'IGST Act 2017 Sections 10-16 (POS, OIDAR, Zero-rated)',
      probedUrls: ['https://cbic-gst.gov.in/pdf/IGST-Act-Updated-30092020.pdf (404)',
                   'https://www.indiacode.nic.in/bitstream/123456789/15690/1/igst_act_2017.pdf (404)',
                   'https://egazette.nic.in/WriteReadData/2017/175852.pdf (ERR - connection refused)'] },
    { claimId: 'CESS_ACT', needed: 'GST (Compensation to States) Act 2017',
      probedUrls: ['https://cbic-gst.gov.in/pdf/Cess-Act-Updated-30092020.pdf (404)',
                   'https://www.indiacode.nic.in/bitstream/123456789/15692/1/gst_compensation_to_states_act_2017.pdf (404)',
                   'https://egazette.nic.in/WriteReadData/2017/175854.pdf (ERR)'] },
    { claimId: 'RATE_1_2017_CTR', needed: 'Notification 1/2017-Central Tax (Rate) - principal slabs 5/12/18/28%',
      probedUrls: ['https://cbic-gst.gov.in/pdf/central-tax-rate/Notfcn-1-CTR-english.pdf (404)',
                   'https://egazette.nic.in/WriteReadData/2017/176335.pdf (ERR)'] },
    { claimId: 'RATE_09_2025_CTR', needed: 'Notification 9/2025-Central Tax (Rate)',
      probedUrls: ['https://cbic-gst.gov.in/pdf/central-tax-rate/Notfctn-09-2025-CTR-English.pdf (404)',
                   'https://egazette.nic.in/WriteReadData/2025/244901.pdf (ERR)',
                   'https://taxinformation.cbic.gov.in/api/v1/document?type=notifications&id=09-2025-CTR (401 Unauthorized)'] },
    { claimId: 'RATE_10_2025_CTR', needed: 'Notification 10/2025-Central Tax (Rate)',
      probedUrls: ['https://cbic-gst.gov.in/pdf/central-tax-rate/Notfctn-10-2025-CTR-English.pdf (404)',
                   'https://egazette.nic.in/WriteReadData/2025/244902.pdf (ERR)'] },
    { claimId: 'RATE_15_2025_CTR', needed: 'Notification 15/2025-Central Tax (Rate)',
      probedUrls: ['https://cbic-gst.gov.in/pdf/central-tax-rate/Notfctn-15-2025-CTR-English.pdf (404)',
                   'https://egazette.nic.in/WriteReadData/2025/244903.pdf (ERR)'] },
    { claimId: 'RATE_16_2025_CTR', needed: 'Notification 16/2025-Central Tax (Rate)',
      probedUrls: ['https://cbic-gst.gov.in/pdf/central-tax-rate/Notfctn-16-2025-CTR-English.pdf (404)',
                   'https://egazette.nic.in/WriteReadData/2025/244904.pdf (ERR)'] },
    { claimId: 'RATE_1_2017_ITR', needed: 'Notification 1/2017-Integrated Tax (Rate) - IGST counterpart',
      probedUrls: ['https://cbic-gst.gov.in/pdf/integrated-tax-rate/Notfcn-1-ITR-english.pdf (404)',
                   'https://egazette.nic.in/WriteReadData/2017/176344.pdf (ERR)'] },
    { claimId: 'RATE_09_2025_ITR', needed: 'Notification 9/2025-Integrated Tax (Rate) IGST counterpart',
      probedUrls: ['https://cbic-gst.gov.in/pdf/integrated-tax-rate/Notfctn-09-2025-ITR-English.pdf (404)'] },
    { claimId: 'RCM_13_2017_CTR', needed: 'Notification 13/2017-Central Tax (Rate) - Goods RCM S.9(3)',
      probedUrls: ['https://cbic-gst.gov.in/pdf/central-tax-rate/Notfcn-13-CTR-english.pdf (404)',
                   'https://egazette.nic.in/WriteReadData/2017/176347.pdf (ERR)'] },
    { claimId: 'RCM_13_2017_ITR', needed: 'Notification 13/2017-Integrated Tax (Rate) - Services RCM IGST',
      probedUrls: ['https://cbic-gst.gov.in/pdf/integrated-tax-rate/Notfcn-13-ITR-english.pdf (404)'] },
    { claimId: 'RCM_S9_4_7_2019', needed: 'Notification 7/2019-Central Tax (Rate) - S.9(4) real-estate RCM',
      probedUrls: ['https://cbic-gst.gov.in/pdf/central-tax-rate/Notfctn-07-2019-CTR-English.pdf (404)',
                   'https://egazette.nic.in/WriteReadData/2019/205638.pdf (ERR)'] },
    { claimId: 'COMP_14_2019_CT', needed: 'Notification 14/2019-Central Tax - Composition S.10(2A) services',
      probedUrls: ['https://cbic-gst.gov.in/pdf/central-tax/Notfctn-14-2019-CT-English.pdf (ERR)',
                   'https://egazette.nic.in/WriteReadData/2019/205580.pdf (ERR)'] },
    { claimId: 'COMP_2_2019_CTR', needed: 'Notification 2/2019-Central Tax (Rate) - Composition rates S.10(2A)',
      probedUrls: ['https://cbic-gst.gov.in/pdf/central-tax-rate/Notfctn-02-2019-CTR-English.pdf (404)',
                   'https://egazette.nic.in/WriteReadData/2019/205628.pdf (ERR)'] },
    { claimId: 'HSNS_CESS', needed: 'Notification 1/2017-Compensation Cess (Rate) - HSNS/standalone Cess',
      probedUrls: ['https://cbic-gst.gov.in/pdf/compensation-cess-rate/Notfcn-1-Cess-english.pdf (404)',
                   'https://cbic-gst.gov.in/pdf/compensation-cess/Notfcn-1-Cess-english.pdf (404)',
                   'https://egazette.nic.in/WriteReadData/2017/176366.pdf (ERR)'] },
  ];

  for (const u of unresolvedFamilies) {
    manifest.push({ ...u, verdict: 'UNRESOLVED', retrievedAt: timestamp });
  }

  // Also keep the already-PROVEN 31-SGST from V3
  manifest.push({
    claimId: '31_SGST_JURISDICTIONS',
    documentTitle: 'SGST-Act | Goods and Services Tax Council',
    authority: 'GST Council of India',
    originalUrl: 'https://www.gstcouncil.gov.in/sgst-act',
    finalUrl: 'https://www.gstcouncil.gov.in/sgst-act',
    httpStatus: 200,
    contentType: 'text/html; charset=UTF-8',
    byteSize: 34740,
    localFile: 'gst_official_sources_v3/sgst_acts_gstcouncil_71df168e.html',
    sha256: '71df168ef7250e34ed10bdfd9cf0eb1d9321a520f61f31de30c17eeaeb76be42',
    retrievedAt: '2026-09-02T08:32:00Z',
    legalTextTermsFound: ['all 31 state names explicitly listed'],
    verdict: 'PROVEN',
    note: 'Jurisdiction listing only — individual SGST Act PDFs require separate download per state'
  });

  const outPath = path.join(outDir, 'source_manifest_v3.json');
  fs.writeFileSync(outPath, JSON.stringify({ generatedAt: timestamp, manifest }, null, 2));

  console.log('\n═══════════════════════════════════════════════════════');
  console.log('GST SOURCE MANIFEST V3 — FINAL CLAIM MATRIX');
  console.log('═══════════════════════════════════════════════════════');
  for (const m of manifest) {
    const tag = m.verdict === 'PROVEN' ? '✅ PROVEN   ' : '❌ UNRESOLVED';
    console.log(`\n[${tag}] ${m.claimId}`);
    if (m.verdict === 'PROVEN') {
      console.log(`  Title   : ${m.documentTitle}`);
      console.log(`  URL     : ${m.finalUrl}`);
      console.log(`  Status  : ${m.httpStatus} | ${m.contentType} | ${m.byteSize} bytes`);
      console.log(`  SHA256  : ${m.sha256}`);
      console.log(`  Terms   : ${(m.legalTextTermsFound||[]).join(', ')}`);
      if (m.note) console.log(`  Note    : ${m.note}`);
    } else {
      console.log(`  Needed  : ${m.needed || m.claimId}`);
      if (m.probedUrls) m.probedUrls.forEach(u => console.log(`  Probed  : ${u}`));
      if (m.reason)     console.log(`  Reason  : ${m.reason}`);
    }
  }

  const proven = manifest.filter(m => m.verdict === 'PROVEN').length;
  const total  = manifest.length;
  console.log(`\n══ SUMMARY: ${proven} PROVEN / ${total - proven} UNRESOLVED out of ${total} claims ══`);
  console.log(`Manifest: ${outPath}`);
}

run();
