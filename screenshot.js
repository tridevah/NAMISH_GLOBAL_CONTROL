const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  
  await page.context().addCookies([{name: 'activeCountryId', value: 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', domain: 'localhost', path: '/'}]);
  
  console.log('Navigating to tax overview...');
  await page.goto('http://localhost:3000/data-hub/tax?country=cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', { waitUntil: 'networkidle' });
  await page.waitForTimeout(3000);
  await page.screenshot({ path: 'C:/Users/Atul1/.gemini/antigravity/brain/66cbea70-fd6b-47b0-a32c-4681abc67020/tax_overview.png' });

  console.log('Navigating to gst rates...');
  await page.goto('http://localhost:3000/data-hub/tax/gst-rates', { waitUntil: 'networkidle' });
  await page.waitForTimeout(3000);
  await page.screenshot({ path: 'C:/Users/Atul1/.gemini/antigravity/brain/66cbea70-fd6b-47b0-a32c-4681abc67020/gst_rates.png' });

  console.log('Navigating to hsn/sac...');
  await page.goto('http://localhost:3000/data-hub/tax/hsn-sac', { waitUntil: 'networkidle' });
  await page.waitForTimeout(3000);
  await page.screenshot({ path: 'C:/Users/Atul1/.gemini/antigravity/brain/66cbea70-fd6b-47b0-a32c-4681abc67020/hsn_sac.png' });

  await browser.close();
  console.log('Done.');
})();
