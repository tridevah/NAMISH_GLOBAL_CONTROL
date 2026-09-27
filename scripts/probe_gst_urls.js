/**
 * GST Source V3 Probe — test candidate URLs before committing to download
 * Probes multiple candidate paths per document family, reports HTTP status + content-type + size.
 */
const https = require('https');
const http  = require('http');

function probe(url) {
  return new Promise(resolve => {
    const mod = url.startsWith('https') ? https : http;
    const req = mod.get(url, {
      rejectUnauthorized: false,
      headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36' },
      timeout: 15000
    }, res => {
      const ct = res.headers['content-type'] || '';
      const cl = res.headers['content-length'] || '?';
      let location = '';
      if ([301,302,303,307,308].includes(res.statusCode)) location = ' -> ' + res.headers.location;
      res.destroy();
      resolve({ url, status: res.statusCode, ct, cl, location });
    });
    req.on('error', e => resolve({ url, status: 'ERR', ct: '', cl: '', location: e.message }));
    req.on('timeout', ()=> { req.destroy(); resolve({ url, status: 'TIMEOUT', ct:'', cl:'', location:'' }); });
  });
}

const families = [

  // ── CGST Act ────────────────────────────────────────────────────────────────
  ['CGST_ACT', 'https://cbic-gst.gov.in/pdf/CGST-Act-Updated-30092020.pdf'],
  ['CGST_ACT', 'https://cbic-gst.gov.in/pdf/CGST-updated-act-1stjuly2017.pdf'],
  ['CGST_ACT', 'https://www.cbic.gov.in/resources//htdocs-cbec/gst/cgst-act.pdf'],
  ['CGST_ACT', 'https://www.indiacode.nic.in/bitstream/123456789/15689/1/cgst_act_2017.pdf'],
  ['CGST_ACT', 'https://www.indiacode.nic.in/bitstream/123456789/15689/3/cgst_act_2017.pdf'],
  ['CGST_ACT', 'https://egazette.nic.in/WriteReadData/2017/175851.pdf'],

  // ── IGST Act ────────────────────────────────────────────────────────────────
  ['IGST_ACT', 'https://cbic-gst.gov.in/pdf/IGST-Act-Updated-30092020.pdf'],
  ['IGST_ACT', 'https://cbic-gst.gov.in/pdf/IGST-updated-act-1stjuly2017.pdf'],
  ['IGST_ACT', 'https://www.indiacode.nic.in/bitstream/123456789/15690/1/igst_act_2017.pdf'],
  ['IGST_ACT', 'https://www.indiacode.nic.in/bitstream/123456789/12749/1/igst_act_2017.pdf'],
  ['IGST_ACT', 'https://egazette.nic.in/WriteReadData/2017/175852.pdf'],

  // ── UTGST Act ───────────────────────────────────────────────────────────────
  ['UTGST_ACT', 'https://cbic-gst.gov.in/pdf/UTGST-Act-Updated-30092020.pdf'],
  ['UTGST_ACT', 'https://www.indiacode.nic.in/bitstream/123456789/7776/1/ut-gst-act.pdf'],
  ['UTGST_ACT', 'https://www.indiacode.nic.in/bitstream/123456789/7776/2/ut-gst-act.pdf'],
  ['UTGST_ACT', 'https://www.indiacode.nic.in/bitstream/123456789/15691/1/utgst_act_2017.pdf'],
  ['UTGST_ACT', 'https://egazette.nic.in/WriteReadData/2017/175853.pdf'],

  // ── GST Compensation Cess Act ────────────────────────────────────────────────
  ['CESS_ACT', 'https://cbic-gst.gov.in/pdf/Cess-Act-Updated-30092020.pdf'],
  ['CESS_ACT', 'https://www.indiacode.nic.in/bitstream/123456789/15692/1/gst_compensation_to_states_act_2017.pdf'],
  ['CESS_ACT', 'https://egazette.nic.in/WriteReadData/2017/175854.pdf'],

  // ── Rate Notifications (Central Tax Rate) ───────────────────────────────────
  // Classic 2017 rates (1/2017-CTR → principal slabs)
  ['RATE_1_2017_CTR', 'https://cbic-gst.gov.in/pdf/central-tax-rate/Notfcn-1-CTR-english.pdf'],
  ['RATE_1_2017_CTR', 'https://cbic-gst.gov.in/pdf/centr-tax-rate-notfcn-28jun2017/Notfcn-01-2017-CTR.pdf'],
  ['RATE_1_2017_CTR', 'https://egazette.nic.in/WriteReadData/2017/176335.pdf'],

  // 2025 Amendments 09/2025-CTR, 10/2025-CTR, 15/2025-CTR, 16/2025-CTR
  ['RATE_09_2025_CTR', 'https://cbic-gst.gov.in/pdf/central-tax-rate/Notfctn-09-2025-CTR-English.pdf'],
  ['RATE_09_2025_CTR', 'https://egazette.nic.in/WriteReadData/2025/244901.pdf'],
  ['RATE_09_2025_CTR', 'https://taxinformation.cbic.gov.in/api/v1/document?type=notifications&id=09-2025-CTR'],

  ['RATE_10_2025_CTR', 'https://cbic-gst.gov.in/pdf/central-tax-rate/Notfctn-10-2025-CTR-English.pdf'],
  ['RATE_10_2025_CTR', 'https://egazette.nic.in/WriteReadData/2025/244902.pdf'],

  ['RATE_15_2025_CTR', 'https://cbic-gst.gov.in/pdf/central-tax-rate/Notfctn-15-2025-CTR-English.pdf'],
  ['RATE_15_2025_CTR', 'https://egazette.nic.in/WriteReadData/2025/244903.pdf'],

  ['RATE_16_2025_CTR', 'https://cbic-gst.gov.in/pdf/central-tax-rate/Notfctn-16-2025-CTR-English.pdf'],
  ['RATE_16_2025_CTR', 'https://egazette.nic.in/WriteReadData/2025/244904.pdf'],

  // IGST rate counterparts
  ['RATE_1_2017_ITR', 'https://cbic-gst.gov.in/pdf/integrated-tax-rate/Notfcn-1-ITR-english.pdf'],
  ['RATE_1_2017_ITR', 'https://egazette.nic.in/WriteReadData/2017/176344.pdf'],
  ['RATE_09_2025_ITR', 'https://cbic-gst.gov.in/pdf/integrated-tax-rate/Notfctn-09-2025-ITR-English.pdf'],

  // ── RCM Notifications ────────────────────────────────────────────────────────
  // 13/2017-CTR (Goods RCM), 13/2017-ITR (Services RCM), 7/2019-CTR (S9(4))
  ['RCM_13_2017_CTR', 'https://cbic-gst.gov.in/pdf/central-tax-rate/Notfcn-13-CTR-english.pdf'],
  ['RCM_13_2017_CTR', 'https://egazette.nic.in/WriteReadData/2017/176347.pdf'],
  ['RCM_13_2017_ITR', 'https://cbic-gst.gov.in/pdf/integrated-tax-rate/Notfcn-13-ITR-english.pdf'],
  ['RCM_7_2019_CTR',  'https://cbic-gst.gov.in/pdf/central-tax-rate/Notfctn-07-2019-CTR-English.pdf'],
  ['RCM_7_2019_CTR',  'https://egazette.nic.in/WriteReadData/2019/205638.pdf'],

  // ── Composition Notifications ────────────────────────────────────────────────
  ['COMP_14_2019_CT', 'https://cbic-gst.gov.in/pdf/central-tax/Notfctn-14-2019-CT-English.pdf'],
  ['COMP_14_2019_CT', 'https://egazette.nic.in/WriteReadData/2019/205580.pdf'],
  ['COMP_2_2019_CTR', 'https://cbic-gst.gov.in/pdf/central-tax-rate/Notfctn-02-2019-CTR-English.pdf'],
  ['COMP_2_2019_CTR', 'https://egazette.nic.in/WriteReadData/2019/205628.pdf'],

  // ── HSNS Cess ────────────────────────────────────────────────────────────────
  ['HSNS_CESS', 'https://cbic-gst.gov.in/pdf/compensation-cess-rate/Notfcn-1-Cess-english.pdf'],
  ['HSNS_CESS', 'https://cbic-gst.gov.in/pdf/compensation-cess/Notfcn-1-Cess-english.pdf'],
  ['HSNS_CESS', 'https://egazette.nic.in/WriteReadData/2017/176366.pdf'],
];

async function run() {
  const results = {};
  for (const [family, url] of families) {
    if (!results[family]) results[family] = [];
    const r = await probe(url);
    results[family].push(r);
    const tag = r.status === 200
      ? (r.ct.includes('pdf') || r.ct.includes('json') ? '✅ DATA' : '⚠️  HTML')
      : `❌ ${r.status}`;
    console.log(`[${family}] ${tag} ${r.status} ${r.cl}b ${r.ct.split(';')[0]} ${url}`);
  }
  // Print only working data URLs
  console.log('\n── CANDIDATE DATA URLs (status=200, pdf/json) ──');
  for (const [fam, list] of Object.entries(results)) {
    const hits = list.filter(r => r.status===200 && (r.ct.includes('pdf') || r.ct.includes('octet')));
    if (hits.length) hits.forEach(h => console.log(`  [${fam}] ${h.url}`));
    else console.log(`  [${fam}] NO DIRECT PDF/BINARY FOUND`);
  }
}
run();
