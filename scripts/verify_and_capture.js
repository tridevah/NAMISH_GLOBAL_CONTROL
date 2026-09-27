const { chromium } = require('playwright');
const path = require('path');
const assert = require('assert');

async function run() {
  const browserURL = 'http://127.0.0.1:9222';
  let browser = await chromium.connectOverCDP(browserURL);
  const page = await browser.contexts()[0].newPage();
  const artifactDir = 'C:\\Users\\Atul1\\.gemini\\antigravity\\brain\\66cbea70-fd6b-47b0-a32c-4681abc67020';

  const INDIA = 'cd8c3030-e91f-09e4-1bb1-14c3e6c8b43d';
  const AFGHANISTAN = 'e57726de-3796-cfbf-94e0-798888dddd5e';

  const testRoutes = [
    '/data-hub',
    '/data-hub/tax',
    '/data-hub/tax/coverage',
    '/data-hub/tax/authorities',
    '/data-hub/tax/scopes',
    '/data-hub/tax/jurisdictions',
    '/data-hub/tax/regimes',
    '/data-hub/tax/components',
    '/data-hub/tax/component-sets',
    '/data-hub/tax/codes',
    '/data-hub/tax/hsn-sac',
    '/data-hub/tax/assignments',
    '/data-hub/tax/currencies',
    '/data-hub/tax/currency-assignments',
    '/data-hub/geography/countries',
    '/data-hub/geography/levels',
    '/data-hub/geography/units',
    '/data-hub/geography/postal-codes'
  ];

  console.log('Testing India Routes...');
  for (const route of testRoutes) {
    const url = `http://localhost:3000${route}?country=${INDIA}`;
    const response = await page.goto(url);
    if (response.status() !== 200) {
      console.error(`ERROR: ${url} returned ${response.status()}`);
      process.exit(1);
    }
  }

  console.log('Testing Afghanistan Routes...');
  for (const route of testRoutes) {
    const url = `http://localhost:3000${route}?country=${AFGHANISTAN}`;
    const response = await page.goto(url);
    if (response.status() !== 200) {
      console.error(`ERROR: ${url} returned ${response.status()}`);
      process.exit(1);
    }
  }

  console.log('All links verified HTTP 200 with both contexts.');

  // Capture requested UI state screenshots
  await page.goto('http://localhost:3000/data-hub');
  await page.waitForTimeout(2000);
  await page.setViewportSize({ width: 1280, height: 800 });
  await page.screenshot({ path: path.join(artifactDir, 'desktop_dashboard_final.png'), fullPage: true });

  await page.setViewportSize({ width: 375, height: 812 });
  await page.screenshot({ path: path.join(artifactDir, 'mobile_dashboard_closed_final.png'), fullPage: true });

  await page.click('button:has(svg.lucide-menu)', { force: true });
  await page.waitForTimeout(1000);
  await page.screenshot({ path: path.join(artifactDir, 'mobile_dashboard_open_final.png'), fullPage: true });

  await page.setViewportSize({ width: 1280, height: 800 });
  await page.goto('http://localhost:3000/data-hub/tax');
  await page.waitForTimeout(2000);
  await page.screenshot({ path: path.join(artifactDir, 'desktop_tax_overview_final.png'), fullPage: true });

  const indiaUrl = `http://localhost:3000/data-hub/geography/units?country=${INDIA}`;
  await page.goto(indiaUrl);
  await page.waitForTimeout(3000);
  await page.screenshot({ path: path.join(artifactDir, 'india_units_proof_final.png'), fullPage: true });

  await page.close();
  await browser.close();
}
run();
