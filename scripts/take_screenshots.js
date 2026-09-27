const { chromium } = require('D:/ANTIGRAVITY_WORKSPACE/scratch/node_modules/playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ viewport: { width: 1280, height: 720 } });
  const page = await context.newPage();

  console.log('Navigating to login...');
  await page.goto('https://control.tridevah.com/login');
  
  console.log('Logging in...');
  await page.fill('input[type="email"]', 'admin@tridevah.com');
  await page.fill('input[type="password"]', 'password123');
  await page.click('button[type="submit"]');
  await page.waitForNavigation();
  console.log('Logged in successfully!');

  // 1. Tax overview
  console.log('Capturing Tax Overview...');
  await page.goto('https://control.tridevah.com/data-hub/tax?country=cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', { waitUntil: 'networkidle' });
  await page.screenshot({ path: 'ui_evidence_tax_overview.png' });

  // 2. GST Rates
  console.log('Capturing GST Rates...');
  await page.goto('https://control.tridevah.com/data-hub/tax/gst-rates?country=cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', { waitUntil: 'networkidle' });
  await page.screenshot({ path: 'ui_evidence_tax_gst.png' });

  // 3. HSN/SAC
  console.log('Capturing HSN/SAC...');
  await page.goto('https://control.tridevah.com/data-hub/tax/hsn-sac?country=cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', { waitUntil: 'networkidle' });
  await page.screenshot({ path: 'ui_evidence_tax_hsn.png' });

  await browser.close();
  console.log('Done!');
})();
