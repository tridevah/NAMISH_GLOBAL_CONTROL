const { chromium } = require('D:/ANTIGRAVITY_WORKSPACE/scratch/node_modules/playwright');
(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ viewport: { width: 1280, height: 800 } });
  const page = await context.newPage();

  await page.goto('https://control.tridevah.com/login');
  await page.fill('input[type="email"]', 'admin@tridevah.com');
  await page.fill('input[type="password"]', 'password123');
  await page.click('button[type="submit"]');
  await page.waitForNavigation();

  // Dashboard — India with country param (card should now be active)
  await page.goto('https://control.tridevah.com/data-hub?country=cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', { waitUntil: 'networkidle' });
  await page.screenshot({ path: 'ss_final_india_card.png' });
  console.log('URL:', page.url());

  // Hard refresh
  await page.reload({ waitUntil: 'networkidle' });
  await page.screenshot({ path: 'ss_final_india_card_refresh.png' });
  console.log('After refresh URL:', page.url());

  await browser.close();
})();
