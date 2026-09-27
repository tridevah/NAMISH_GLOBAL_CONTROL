const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const outDir = path.join(__dirname, '../gst_sources');

function sha256(buf) {
  return crypto.createHash('sha256').update(buf).digest('hex');
}

async function fetchByClickingActTitle(url, actTitleSubstr, browser) {
  const context = browser.contexts()[0];
  const page = await context.newPage();
  
  let pdfBuffer = null;
  page.on('response', async (res) => {
    const ct = res.headers()['content-type'] || '';
    if (ct.includes('application/pdf') || ct.includes('octet-stream')) {
      try {
        const buf = await res.body();
        if (buf.length > 5000) pdfBuffer = buf;
      } catch(e) {}
    }
  });

  try {
    await page.goto(url, { waitUntil: 'networkidle', timeout: 30000 });
    
    // find the link by clicking the exact text
    // The link might be an anchor tag containing the title
    const links = await page.$$('a');
    let clicked = false;
    for (const a of links) {
        const text = await a.innerText();
        if (text && text.includes(actTitleSubstr)) {
            console.log(`Clicking link matching: ${actTitleSubstr}`);
            // Wait for response after click
            const [response] = await Promise.all([
                page.waitForResponse(res => {
                    const ct = res.headers()['content-type'] || '';
                    return (ct.includes('application/pdf') || ct.includes('octet-stream'));
                }, { timeout: 30000 }).catch(() => null),
                a.click()
            ]);
            clicked = true;
            if (response) {
                pdfBuffer = await response.body();
            }
            break;
        }
    }
    if (!clicked) console.log(`Could not find link for ${actTitleSubstr}`);
    await page.waitForTimeout(3000); // give time for download if it triggered differently
  } catch(e) {
      console.log('Error:', e.message);
  }
  
  await page.close();
  return pdfBuffer;
}

async function run() {
  const browser = await chromium.connectOverCDP('http://localhost:9222');
  
  const acts = [
      { id: 'CGST', url: 'https://www.indiacode.nic.in/indiacode/handle/123456789/15689?view_type=browse', match: 'Central Goods and Services Tax Act' },
      { id: 'IGST', url: 'https://www.indiacode.nic.in/indiacode/handle/123456789/2251?view_type=browse', match: 'Integrated Goods and Services Tax Act' },
      { id: 'COMP_CESS', url: 'https://www.indiacode.nic.in/indiacode/handle/123456789/2253?view_type=browse', match: 'Goods and Services Tax (Compensation to States) Act' },
      { id: 'HSNS_CESS', url: 'https://www.indiacode.nic.in/indiacode/handle/123456789/22084?view_type=browse', match: 'Health and Education Cess' } // Or maybe 'Finance Act'? Let's check HSNS cess
  ];
  
  for (const act of acts) {
      console.log(`Fetching ${act.id}...`);
      const buf = await fetchByClickingActTitle(act.url, act.match, browser);
      if (buf) {
          const sha = sha256(buf);
          console.log(`${act.id} Success! SHA: ${sha}`);
          fs.writeFileSync(path.join(outDir, `${act.id}_${sha.slice(0,8)}.pdf`), buf);
      } else {
          console.log(`${act.id} Failed.`);
      }
  }

  await browser.close();
}

run().catch(console.error);
