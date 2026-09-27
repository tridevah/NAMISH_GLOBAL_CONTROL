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

  // 1. Dashboard — no country
  await page.goto('https://control.tridevah.com/data-hub', { waitUntil: 'networkidle' });
  await page.screenshot({ path: 'ss_dash_no_country.png' });

  // 2. Dashboard — India selected (UNRESOLVED ? card active)
  await page.goto('https://control.tridevah.com/data-hub?country=cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d', { waitUntil: 'networkidle' });
  await page.screenshot({ path: 'ss_dash_india.png' });

  // 3. Hard refresh preserves state
  await page.reload({ waitUntil: 'networkidle' });
  await page.screenshot({ path: 'ss_dash_india_refresh.png' });

  console.log('Done');
  await browser.close();
})();
