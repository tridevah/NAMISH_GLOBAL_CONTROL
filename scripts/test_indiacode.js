const { chromium } = require('playwright');
async function test() {
  const browser = await chromium.connectOverCDP('http://localhost:9222');
  const context = browser.contexts()[0];
  const page = await context.newPage();
  await page.goto('https://www.indiacode.nic.in/indiacode/handle/123456789/15689?view_type=browse', { waitUntil: 'networkidle', timeout: 30000 });
  const links = await page.evaluate(() => {
     return Array.from(document.querySelectorAll('a')).map(a => ({ text: a.innerText.trim(), href: a.href })).filter(a => a.href.includes('bitstream') || a.href.endsWith('.pdf'));
  });
  console.log('Links found:', links);
  await page.close();
  await browser.close();
}
test().catch(console.error);
