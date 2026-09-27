const { chromium } = require('D:/ANTIGRAVITY_WORKSPACE/scratch/node_modules/playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ viewport: { width: 1280, height: 720 } });
  const page = await context.newPage();

  await page.goto('https://control.tridevah.com/login');
  await page.fill('input[type="email"]', 'admin@tridevah.com');
  await page.fill('input[type="password"]', 'password123');
  await page.click('button[type="submit"]');
  await page.waitForNavigation();

  // Dashboard with India selected - should show Tax & Compliance as a real link
  await page.goto('https://control.tridevah.com/data-hub?country=cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', { waitUntil: 'networkidle' });
  await page.screenshot({ path: 'ui_evidence_dashboard_india_tax_active.png' });
  console.log('Dashboard screenshot done!');
  await browser.close();
})();
